#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongo_mapper'

get /([a-z]+)(?:\.(\w+))?/ do
  if !entities.include?(params[:captures][0])
    raise Sinatra::NotFound, "Four oh four."
  end
  if params[:captures][1] and ![:json, :jsonp].include?(params[:captures][1])
    raise Sinatra::NotFound, "Unsupported format."
  end
  

  entity = params[:captures][0].camelize.constantize
  
  # figure out which sections are requested
  sections = (params[:sections] || '').split(',').map do |section|
    entity.fields.keys.include?(section.to_sym) ? section.to_sym : nil
  end.compact
  
  fields = entity.fields[:basic] + sections.map {|source| entity.fields[source]}.flatten
  document = entity.first :conditions => {entity.search_key => params[entity.search_key]}, :fields => fields
  
  if document
    response['Content-Type'] = 'application/json'
    
    if params[:captures][1] == 'jsonp' and params[:callback]
      jsonp json(document), params[:callback]
    else
      json document
    end
  else
    raise Sinatra::NotFound, "#{params[:captures][0].capitalize} not found"
  end
end

def json(legislator)
  {:legislator => legislator}.to_json
end

def jsonp(json, callback)
  "#{callback}(#{json});"
end

def config
  @config ||= YAML.load_file 'config.yml'
end

def sources
  @sources ||= Dir.glob('sources/*.rb').map do |source|
    File.basename source, File.extname(source)
  end
end

def entities
  @entities ||= Dir.glob('entities/*.rb').map do |entity|
    File.basename entity, File.extname(entity)
  end
end

configure do
  sources.each do |source|
    load "sources/#{source}.rb"
  end
  entities.each do |entity|
    load "entities/#{entity}.rb"
  end
  
  Sunlight::Base.api_key = config[:sunlight_api_key]
  
  MongoMapper.connection = config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
end