require 'rubygems'
require 'sunlight'
require 'mongo_mapper'
require 'pony'

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

Dir.glob('models/*.rb').each {|model| load model}
Dir.glob('sources/*.rb').each {|model| load model}


class Report
  include MongoMapper::Document
  
  key :status, String, :required => true
  key :source, String, :required => true
  key :message, String
  
  timestamps!
  
  
  def self.file(status, source, message, objects = {})
    report = Report.new :source => source.to_s, :status => status, :message => message
    report.attributes = objects
    puts report.to_s
    report.save
    report
  end
  
  def self.success(source, message, objects = {})
    file 'SUCCESS', source, message, objects
  end
  
  def self.failure(source, message, objects = {})
    report = file 'FAILURE', source, message, objects
    send_email report
  end
  
  def self.warning(source, message, objects = {})
    report = file 'WARNING', source, message, objects
    send_email report
  end
  
  def self.latest(model, size = 1)
    reports = Report.all :conditions => {:source => model.to_s}, :order => "created_at DESC", :limit => size
    size > 1 ? reports : reports.first
  end
  
  def self.send_email(report)
    Pony.mail email.merge(:subject => report.to_s, :body => report.attributes.inspect)
  end
  
  def self.email=(details)
    @email = details
  end
  
  def self.email
    @email
  end
  
  def to_s
    "[#{source}] #{status}: #{message}"
  end
end

configure do
  Report.email = config[:email]
end