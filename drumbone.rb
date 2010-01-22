#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'config/environment'

get /^\/(#{models.join '|'})(?:\.json)?$/ do
  response['Content-Type'] = 'application/json'
  model = params[:captures][0].camelize.constantize
  
  sections = params[:sections] ? (params[:sections] || '').split(',') + [:basic] : model.fields.keys
  fields = sections.uniq.map {|section| model.fields[section.to_sym]}.flatten.compact
  document = model.first :conditions => {model.search_key => params[model.search_key]}, :fields => fields
  
  if document
    json document, params[:callback]
  else
    raise Sinatra::NotFound, "#{model} not found"
  end
end

def json(document, callback = nil)
  model = document.class
  attributes = document.attributes
  attributes.delete :_id
  json = {
    model.to_s.underscore => attributes, 
    :sections => model.fields.keys.sort_by {|x, y| x == :basic ? -1 : x.to_s <=> y.to_s}
  }.to_json
  callback ? "#{callback}(#{json});" : json
end