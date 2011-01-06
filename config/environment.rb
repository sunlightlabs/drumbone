require 'sinatra'
require 'mongo_mapper'

def config
  @config ||= YAML.load_file 'config/config.yml'
end

# We need to connect to Mongo first, then define the models, and then set the email settings
# Thus the need for two configure blocks

configure do
  MongoMapper.connection = Mongo::Connection.new config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
end


require 'analytics'
require 'report'

Dir.glob('models/*.rb').each {|model| load model}
Dir.glob('sources/*.rb').each {|model| load model}

require 'sunlight'

configure do
  Report.email = config[:email]
  Sunlight::Base.api_key = config[:sunlight_api_key]
  VoteSmart.api_key = config[:votesmart_api_key]
end