class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :active, Boolean, :required => true
  key :chamber, String, :required => true
  
  timestamps!
  
  def self.active
    all :conditions => {:active => true}
  end
end