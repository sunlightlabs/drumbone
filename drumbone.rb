#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongomapper'

require 'sunlight'
require 'legislator'

get '/' do
  Legislator.all.map do |legislator|
    "#{legislator.title}. #{legislator.last_name}"
  end.join "\n<br/>"
end



def config
  @config ||= YAML.load_file 'config.yml'
end

configure do
  @sources = Dir.glob('sources/*.rb').map do |source|
    load source
    File.basename source, File.extname(source)
  end
  
  Sunlight::Base.api_key = config[:sunlight_api_key]
  
  MongoMapper.connection = config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
end