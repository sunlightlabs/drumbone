require 'rubygems'
require 'mongo_mapper'

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
  
  key :status, String, :required => true
  key :source, String, :required => true
  key :message, String
  
  timestamps!
  
  def self.file(status, source, message, objects = nil)
    report = Report.new :source => source.to_s, :status => status, :message => message
    report.attributes = {:objects => objects} if objects
    report.save
  end
  
  def self.success(source, message, objects = nil)
    file "SUCCESS", source, message, objects
  end
  
  def self.failure(source, message, objects = nil)
    file "FAILURE", source, message, objects
  end
  
end