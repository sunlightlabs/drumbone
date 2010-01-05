#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongomapper'

get '/' do
  Legislator.all.map do |legislator|
    "#{legislator.title}. #{legislator.last_name}"
  end.join "\n<br/>"
end

configure do
  @config = YAML.load_file 'config.yml'
  
  MongoMapper.connection = @config[:database][:hostname]
  MongoMapper.database = @config[:database][:database]
end

class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :first_name, String, :required => true
  key :nickname, String
  key :last_name, String, :required => true
  key :title, String, :required => true
  key :state, String, :required => true
  key :party, String
  
  timestamps!
end