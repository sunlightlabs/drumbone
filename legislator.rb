class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :active, Boolean, :required => true
  key :chamber, String, :required => true
  
  timestamps!
  
  # basic fields will always be returned as part of the JSON response
  def self.fields
    {:basic => [:created_at, :updated_at, :bioguide_id, :chamber, :active],
     :bio => [:first_name, :nickname, :last_name, :state, :district, :party, :title, :gender, :phone, :website, :twitter_id, :youtube_url]
    }
  end
  
  def self.active
    all :conditions => {:active => true}
  end
end