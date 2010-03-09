#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'environment'


get /^\/api\/(legislator)\.(json)$/ do
  fields = fields_for Legislator, params[:sections]
  conditions = conditions_for Legislator.unique_keys, params
  
  unless conditions.any? and legislator = Legislator.first(:conditions => conditions, :fields => fields)
    halt 404, "Legislator not found by that ID"
  end
  
  json Legislator, attributes_for(legislator, fields), params[:callback]
end

get /^\/api\/(bill)\.(json)$/ do
  fields = fields_for Bill, params[:sections]
  conditions = conditions_for Bill.unique_keys, params
  
  unless conditions.any? and bill = Bill.first(:conditions => conditions, :fields => fields)
    raise Sinatra::NotFound, "Bill not found"
  end
  
  json Bill, attributes_for(bill, fields), params[:callback]
end

get /^\/api\/(roll)\.(json)$/ do
  fields = fields_for Roll, params[:sections]
  conditions = conditions_for Roll.unique_keys, params
  
  unless conditions.any? and roll = Roll.first(:conditions => conditions, :fields => fields)
    raise Sinatra::NotFound, "Roll call not found"
  end
  
  json Roll, attributes_for(roll, fields), params[:callback]
end

get /^\/api\/(bills)\.(json)$/ do
  fields = fields_for Bill, params[:sections]
  conditions = conditions_for Bill.search_keys, params
  
  if conditions[:enacted]
    if ["true", "1"].include? conditions[:enacted]
      conditions[:enacted] = true
    elsif ["false", "0"].include? conditions[:enacted]
      conditions[:enacted] = false
    else
      conditions.delete :enacted
    end
  end
  
  bills = Bill.all({
    :conditions => conditions,
    :fields => fields,
    :order => "#{params[:order] || 'introduced_at'} DESC"
  }.merge(pagination_for(params)))
  
  json Bill, bills.map {|bill| attributes_for bill, fields}, params[:callback]
end

get /^\/api\/(rolls)\.(json)$/ do
  fields = fields_for Roll, params[:sections]
  conditions = conditions_for Roll.search_keys, params
  
  rolls = Roll.all({
    :conditions => conditions,
    :fields => fields,
    :order => "#{params[:order] || 'voted_at'} DESC"
  }.merge(pagination_for(params)))
  
  json Roll, rolls.map {|roll| attributes_for roll, fields}, params[:callback]
end


helpers do
  
  def json(model, object, callback = nil)
    response['Content-Type'] = 'application/json'
    
    key = model.to_s.underscore
    key = key.pluralize if object.is_a?(Array)
    
    json = {key => object}.to_json
    
    callback ? "#{callback}(#{json});" : json
  end


  def conditions_for(keys, params)
    conditions = {}
    keys.each do |key|
      conditions = conditions.merge(key => params[key]) if params[key]
    end
    conditions
  end

  def pagination_for(params)
    default_per_page = 20
    max_per_page = 500
    max_page = 200000000 # let's keep it realistic
    
    # rein in per_page to somewhere between 1 and the max
    per_page = (params[:per_page] || default_per_page).to_i
    per_page = default_per_page if per_page <= 0
    per_page = max_per_page if per_page > max_per_page
    
    # valid page number, please
    page = (params[:page] || 1).to_i
    page = 1 if page <= 0 or page > max_page
    
    {:limit => per_page, :offset => (page - 1 ) * per_page}
  end

  def fields_for(model, sections)
    if sections.include?('basic')
      sections.delete 'basic' # does nothing if not present
      sections += model.basic_fields.map {|field| field.to_s}
    end
    sections.uniq
  end

  def attributes_for(document, fields)
    attributes = document.attributes
    
    [:created_at, :_id, :id].each {|field| attributes.delete field.to_s}
    if fields.any?
      attributes.keys.each {|key| attributes.delete(key) unless fields.include?(key)}
    end
    
    attributes
  end
  
end