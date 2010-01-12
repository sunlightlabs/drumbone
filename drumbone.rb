#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongomapper'

require 'legislator'

Dir.glob('sources/*.rb').each {|source| load source}

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