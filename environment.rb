require 'rubygems'
require 'sunlight'
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


require 'api'
require 'report'

Dir.glob('models/*.rb').each {|model| load model}
Dir.glob('sources/*.rb').each {|model| load model}


configure do
  Report.email = config[:email]
end