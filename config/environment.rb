require 'rubygems'
require 'mongo_mapper'

Dir.glob('sources/*.rb').each {|source| load source}
Dir.glob('models/*.rb').each {|model| load model}

def models
  @models = Dir.glob('models/*.rb').map do |model|
    File.basename model, File.extname(model)
  end
end

def config
  @config ||= YAML.load_file 'config/config.yml'
end

configure do
  Sunlight::Base.api_key = config[:sunlight_api_key]
  
  MongoMapper.connection = config[:database][:hostname]
  MongoMapper.database = config[:database][:database]
end


class Report
  include MongoMapper::Document
  
  key :source, String, :required => true
  key :status, String, :required => true
  
  timestamps!
  
end