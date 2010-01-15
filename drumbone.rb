#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongo_mapper'

require 'sunlight'
require 'legislator'

get /legislators(?:\.(\w+))?/ do
  
  # figure out which sections are requested
  requested_sources = (params[:sections] || '').split(',').map do |section|
    sources.include?(section) ? section.camelize.constantize : nil
  end.compact
  
  # get the combined list of fields to ask for
  fields = Legislator.fields + requested_sources.map {|source| source.fields}.flatten
  
  legislator = Legislator.first :conditions => {:bioguide_id => params[:bioguide_id]}, :fields => fields
  
  if legislator
    response['Content-Type'] = 'application/json'
    
    if params[:captures] == ['jsonp'] and params[:callback]
      jsonp json(legislator), params[:callback]
    else
      json legislator
    end
  else
    raise Sinatra::NotFound, "Four oh four"
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

configure do
  sources.each do |source|
    load "sources/#{source}.rb"
  end
  
  Sunlight::Base.api_key = config[:sunlight_api_key]
  
  MongoMapper.connection = config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
end