require 'json/ext'

# hack to stop ActiveSupport from taking away my JSON C extension
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    alias_method :to_json_from_gem, :to_json
  end
end

require 'sinatra'
require 'mongo_mapper'

# restore the original to_json on core objects (damn you ActiveSupport)
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    alias_method :to_json, :to_json_from_gem
  end
end


# insist on my API-wide timestamp format
Time::DATE_FORMATS.merge!(:default => Proc.new {|t| t.xmlschema})

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