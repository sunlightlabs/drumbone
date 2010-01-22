# Entity classes must support four class level methods:
#
# search_key: returns the search key used to look up an entity.
# fields: returns a hash of keys to sections of fields. 
#   :basic must be supported, and should contain all database keys, including timestamps.
#   :all may not be used - it is a special keyword to get all fields.
#   
# active: returns an array of the currently active subset of the entity.
# sync: Used to sync the entity's concept of "active" members. Will be run nightly via rake.

require 'sunlight'

class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :govtrack_id, String, :required => true
  key :active, Boolean, :required => true
  key :chamber, String, :required => true
  
  timestamps!
  
  def self.search_key
    :bioguide_id
  end
  
  # basic fields will always be returned as part of the JSON response
  def self.fields
    {:basic => [:created_at, :updated_at, :bioguide_id, :govtrack_id, :chamber, :active],
     :bio => [:first_name, :nickname, :last_name, :state, :district, :party, :title, :gender],
     :contact => [:phone, :website, :twitter_id, :youtube_url]
    }
  end
  
  def self.active
    all :conditions => {:active => true}
  end
  
  def self.update
    old_legislators = self.active
    
    Sunlight::Legislator.all_where(:in_office => 1).each do |api_legislator|
      if legislator = Legislator.first(:conditions => {:bioguide_id => api_legislator.bioguide_id})
        old_legislators.delete legislator
        puts "[Legislator #{legislator.bioguide_id}] Updated"
      else
        legislator = Legislator.new :bioguide_id => api_legislator.bioguide_id
        puts "[Legislator #{legislator.bioguide_id}] Created"
      end
      
      legislator.attributes = {
        :active => true,
        :chamber => {
            'Rep' => 'House',
            'Sen' => 'Senate',
            'Del' => 'House',
            'Com' => 'House'
          }[api_legislator.title],
        
        :crp_id => api_legislator.crp_id,
        :govtrack_id => api_legislator.govtrack_id,
        :votesmart_id => api_legislator.votesmart_id,
        :fec_id => api_legislator.fec_id,
      }
      
      legislator.save
    end
    
    old_legislators.each do |legislator|
      legislator.update_attribute :active, false
      puts "[Legislator #{legislator.bioguide_id}] Marked Inactive"
    end
  end
  
end