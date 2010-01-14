class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :active, Boolean, :required => true
  key :chamber, String, :required => true
  
  timestamps!
  
  # will always be returned as part of the JSON response
  def self.fields
    [:created_at, :updated_at, :bioguide_id, :chamber, :active]
  end
  
  def self.active
    all :conditions => {:active => true}
  end
end