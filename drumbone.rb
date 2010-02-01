#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'environment'


get /^\/(legislator|bill|roll)\.json$/ do
  model = params[:captures][0].camelize.constantize
  
  unless document = model.first(
      :conditions => conditions_for(model.unique_keys, params), 
      :fields => fields_for(model, params[:sections]))
    raise Sinatra::NotFound, "#{model} not found"
  end
  
  json model, attributes_for(document), params[:callback]
end

get /^\/bills\.json$/ do
  bills = Bill.all(
    :conditions => conditions_for(Bill.search_keys, params).
      merge(:session => (params[:session] || Bill.current_session.to_s)), 
    :fields => fields_for(Bill, params[:sections]),
    :limit => (params[:per_page] || 20).to_i,
    :offset => ((params[:page] || 1).to_i - 1 ) * (params[:per_page] || 20).to_i,
    :order => "introduced_at DESC"
  )
  
  json Bill, bills.map {|bill| attributes_for bill}, params[:callback]
end


def json(model, object, callback = nil)
  response['Content-Type'] = 'application/json'
  
  key = model.to_s.underscore
  key = key.pluralize if object.is_a?(Array)
  
  json = {
    key => object,
    :sections => model.fields.keys.sort_by {|x, y| x == :basic ? -1 : x.to_s <=> y.to_s}
  }.to_json
  
  callback ? "#{callback}(#{json});" : json
end


def conditions_for(keys, params)
  keys.each do |key|
    return {key => params[key]} if params[key]
  end
  {keys.first => nil} # default
end

def fields_for(model, sections)
  keys = sections ? (sections || '').split(',') + [:basic] : model.fields.keys
  keys.uniq.map {|section| model.fields[section.to_sym]}.flatten.compact
end

def attributes_for(document)
  attributes = document.attributes
  attributes.delete :_id
  attributes
end