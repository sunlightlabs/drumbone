#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongo_mapper'
Dir.glob('sources/*.rb').each {|source| load source}
Dir.glob('models/*.rb').each {|model| load model}

get /([a-z]+)(?:\.(\w+))?/ do
  if !models.include?(params[:captures][0])
    raise Sinatra::NotFound, "Four oh four."
  end
  if params[:captures][1] and ![:json, :jsonp].include?(params[:captures][1].to_sym)
    raise Sinatra::NotFound, "Unsupported format."
  end
  
  model = params[:captures][0].camelize.constantize
  
  # figure out which sections are requested
  sections = ['all','all,'].include?(params[:sections]) ? model.fields.keys : (params[:sections] || '').split(',')
  
  fields = model.fields[:basic] + sections.map {|section| model.fields[section.to_sym]}.flatten.compact
  document = model.first :conditions => {model.search_key => params[model.search_key]}, :fields => fields
  
  if document
    response['Content-Type'] = 'application/json'
    
    if params[:captures][1] == 'jsonp' and params[:callback]
      jsonp json(model, document), params[:callback]
    else
      json model, document
    end
  else
    raise Sinatra::NotFound, "#{params[:captures][0].capitalize} not found"
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


def config
  @config ||= YAML.load_file 'config.yml'
end

def models
  @models ||= Dir.glob('models/*.rb').map do |model|
    File.basename model, File.extname(model)
  end
end

configure do
  Sunlight::Base.api_key = config[:sunlight_api_key]
  
  MongoMapper.connection = config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
end

class Report
  include MongoMapper::Document
  
  key :source, String, :required => true
  key :status, String, :required => true
  
  timestamps!
  
end