require 'pony'

class Report
  include MongoMapper::Document
  
  key :status, String, :required => true
  key :source, String, :required => true
  key :message, String
  key :elapsed_time, Float
  
  timestamps!
  
  
  def self.file(status, source, message, objects = {})
    report = Report.new :source => source.to_s, :status => status, :message => message
    report.attributes = objects
    report.save
    
    puts report.to_s
    send_email report if ['FAILURE', 'WARNING'].include?(status.to_s)
    
    report
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
    "[#{status}] #{source}#{elapsed_time ? " [#{elapsed_time} sec]" : ""}\n    #{message}"
  end
end