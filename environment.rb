require 'rubygems'
require 'sinatra'
require 'sunlight'

gem 'activesupport', '= 2.3.5'
gem 'mongo', '=1.0.7'
gem 'mongo_ext', '= 0.19.3'
gem 'mongo_mapper', '= 0.8.3'

require 'active_support' 
require 'mongo'
require 'mongo_mapper'

def config
  @config ||= YAML.load_file 'config/config.yml'
end

# We need to connect to Mongo first, then define the models, and then set the email settings
# Thus the need for two configure blocks

configure do
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
  Sunlight::Base.api_key = config[:sunlight_api_key]
  VoteSmart.api_key = config[:votesmart_api_key]
end