require 'rubygems'
require 'mongo_mapper'

Dir.glob('models/*.rb').each {|model| load model}
Dir.glob('sources/*.rb').each {|model| load model}

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
  
  MongoMapper.ensure_indexes!
end


class Report
  include MongoMapper::Document
  
  key :status, String, :required => true
  key :source, String, :required => true
  key :message, String
  
  timestamps!
  
  def self.file(status, source, message, objects = {})
    report = Report.new :source => source.to_s, :status => status, :message => message
    report.attributes = objects
    puts "[#{source}] #{status}: #{message}"
    report.save
  end
  
  def self.success(source, message, objects = {})
    file 'SUCCESS', source, message, objects
  end
  
  def self.failure(source, message, objects = {})
    file 'FAILURE', source, message, objects
  end
  
  def self.warning(source, message, objects = {})
    file 'WARNING', source, message, objects
  end
  
  def self.latest(model, size = 1)
    rs = Report.all :conditions => {:source => model.to_s}, :order => "created_at DESC", :limit => size
    size > 1 ? rs : rs.first
  end
end