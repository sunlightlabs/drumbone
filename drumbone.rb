#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'mongomapper'

require 'sunlight'
require 'legislator'

get '/legislators' do
#   params[:sections].split(',').each do |section|
#     source = section.camelize.constantize rescue nil
#   end
  legislator = Legislator.first :conditions => {:bioguide_id => params[:bioguide_id]}
  if legislator
    legislator.to_json
  else
    raise Sinatra::NotFound, "Four oh four"
  end
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