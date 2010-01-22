#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongo_mapper'
Dir.glob('sources/*.rb').each {|source| load source}
Dir.glob('models/*.rb').each {|model| load model}

def models
  @models = Dir.glob('models/*.rb').map do |model|
    File.basename model, File.extname(model)
  end
end

def config
  @config ||= YAML.load_file 'config.yml'
end

configure do
  Sunlight::Base.api_key = config[:sunlight_api_key]
  
  MongoMapper.connection = config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
end



get /^\/(#{models.join '|'})(?:\.json)?$/ do
  response['Content-Type'] = 'application/json'
  model = params[:captures][0].camelize.constantize
  
  sections = ['all','all,'].include?(params[:sections]) ? model.fields.keys : (params[:sections] || '').split(',')
  fields = model.fields[:basic] + sections.map {|section| model.fields[section.to_sym]}.flatten.compact
  document = model.first :conditions => {model.search_key => params[model.search_key]}, :fields => fields
  
  if document
    if params[:callback]
      jsonp json(model, document), params[:callback]
    else
      json model, document
    end
  else
    raise Sinatra::NotFound, "#{model} not found"
  end
end


def json(model, document)
  attributes = document.attributes
  attributes.delete :_id
  {
    model.to_s.underscore => attributes, 
    :sections => model.fields.keys.reject {|k| k == :basic} << 'all'
  }.to_json
end

def jsonp(json, callback)
  "#{callback}(#{json});"
end


class Report
  include MongoMapper::Document
  
  key :source, String, :required => true
  key :status, String, :required => true
  
  timestamps!
  
end