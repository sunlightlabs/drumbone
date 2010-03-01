require 'rubygems'
require 'sinatra'
require 'sunlight'

gem 'activesupport', '= 2.3.5' 
gem 'mongo', ">= 0.18.3", '< 1.0'
gem 'mongo_ext', ">= 0.18.3", '< 1.0'
gem 'mongo_mapper', '>= 0.7', '< 0.8'
require 'active_support' 
require 'mongo'
require 'mongo_mapper'

def config
  @config ||= YAML.load_file 'config/config.yml'
end

configure do
  Sunlight::Base.api_key = config[:sunlight_api_key]
  
  MongoMapper.connection = Mongo::Connection.new config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
  
  set :public, '.'
end


require 'analytics'
require 'report'

Dir.glob('models/*.rb').each {|model| load model}
Dir.glob('sources/*.rb').each {|model| load model}


configure do
  Report.email = config[:email]
end