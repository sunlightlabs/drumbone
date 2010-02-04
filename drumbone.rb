#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'environment'


before do
  
  halt 403 unless ApiKey.allowed?(params[:apikey])
  response['Content-Type'] = 'application/json'
end

error 403 do
  'API key required, you can obtain one from http://services.sunlightlabs.com/accounts/register/'
end

get /^\/(legislator|bill|roll)\.json$/ do
  model = params[:captures][0].camelize.constantize
  fields = fields_for Bill, params[:sections]
  
  unless document = model.first(
      :conditions => conditions_for(model.unique_keys, params), 
      :fields => fields)
    raise Sinatra::NotFound, "#{model} not found"
  end
  
  json model, attributes_for(document, fields), params[:callback]
end

get /^\/bills\.json$/ do
  fields = fields_for Bill, params[:sections]
  
  bills = Bill.all(
    :conditions => conditions_for(Bill.search_keys, params).
      merge(:session => (params[:session] || Bill.current_session.to_s)), 
    :fields => fields,
    :limit => (params[:per_page] || 20).to_i,
    :offset => ((params[:page] || 1).to_i - 1 ) * (params[:per_page] || 20).to_i,
    :order => "#{params[:order] || 'introduced_at'} DESC"
  )
  
  json Bill, bills.map {|bill| attributes_for bill, fields}, params[:callback]
end


def json(model, object, callback = nil)
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
  {}
end

def fields_for(model, sections)
  keys = sections ? (sections || '').split(',') : model.fields.keys
  keys.uniq.map {|section| model.fields[section.to_sym]}.flatten.compact
end

def attributes_for(document, fields)
  attributes = document.attributes
  attributes.keys.each {|key| attributes.delete(key) unless fields.include?(key.to_sym)}
  attributes
end