# Entity classes must support three class level methods:
#
# search_key: returns the search key used to look up an entity.
# fields: returns a hash of keys to sections of fields. At a minimum, :basic must be a supported key.
# active: returns an array of the currently active subset of the entity.

class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :active, Boolean, :required => true
  key :chamber, String, :required => true
  
  timestamps!
  
  def self.search_key
    :bioguide_id
  end
  
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