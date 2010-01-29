# Models must support a couple class level methods:
#
# fields: returns a hash of keys to sections of fields. 
#   :basic must be supported, and should contain all database keys and needed identifiers, including timestamps.
#   
# update: Do whatever you have to do to update the model.

require 'sunlight'

class Legislator
  include MongoMapper::Document
  
  key :bioguide_id, String, :required => true
  key :govtrack_id, String, :required => true
  key :in_office, Boolean, :required => true
  key :chamber, String, :required => true
  
  ensure_index :bioguide_id
  ensure_index :govtrack_id
  ensure_index :in_office
  ensure_index :chamber
  
  timestamps!
  
  def self.unique_keys
    [:bioguide_id, :govtrack_id]
  end
  
  # basic fields will always be returned as part of the JSON response
  def self.fields
    {:basic => [:created_at, :updated_at, :bioguide_id, :govtrack_id, :chamber, :in_office],
     :bio => [:first_name, :nickname, :last_name, :state, :district, :party, :title, :gender],
     :contact => [:phone, :website, :twitter_id, :youtube_url],
     :statistics => [:bills_sponsored, :bills_cosponsored, :resolutions_sponsored, :resolutions_cosponsored]
    }
  end
  
  def self.update_statistics
    start = Time.now
    legislators = all :conditions => {:in_office => true}
    
    legislators.each do |legislator|
      legislator.attributes = {
        :bills_sponsored => Bill.bills_sponsored(legislator),
        :bills_cosponsored => Bill.bills_cosponsored(legislator),
        :resolutions_sponsored => Bill.resolutions_sponsored(legislator),
        :resolutions_cosponsored => Bill.resolutions_cosponsored(legislator)
      }
      legislator.save
    end
    
    Report.success self, "Updated bill statistics for all active legislators", {:elapsed_time => Time.now - start}
  end
  
  def self.update
    initialize if Legislator.count == 0
    
    active_count = 0
    inactive_count = 0
    
    start = Time.now
    
    old_legislators = all :conditions => {:in_office => true}
    
    Sunlight::Legislator.all_where(:in_office => 1).each do |api_legislator|
      if legislator = Legislator.first(:conditions => {:bioguide_id => api_legislator.bioguide_id})
        old_legislators.delete legislator
        # puts "[Legislator #{legislator.bioguide_id}] Updated"
      else
        legislator = Legislator.new :bioguide_id => api_legislator.bioguide_id
        # puts "[Legislator #{legislator.bioguide_id}] Created"
      end
      
      legislator.attributes = attributes_from api_legislator
      legislator.save
      
      active_count += 1
    end
    
    old_legislators.each do |legislator|
      legislator.update_attribute :in_office, false
      # puts "[Legislator #{legislator.bioguide_id}] Marked Inactive"
      inactive_count += 1
    end
    
    Report.success self, "Created/updated #{active_count} active legislators, marked #{inactive_count} as inactive", {:elapsed_time => Time.now - start}
  end
  
  
  def self.initialize
    # puts "Initializing out-of-office legislators..."
    
    start = Time.now
    
    initialized_count = 0
    Sunlight::Legislator.all_where(:in_office => 0).each do |api_legislator|
      legislator = Legislator.new :bioguide_id => api_legislator.bioguide_id
      # puts "[Legislator #{legislator.bioguide_id}] Created"
      
      legislator.attributes = attributes_from api_legislator
      legislator.save
      
      initialized_count += 1
    end
    
    Report.success self, "Initialized #{initialized_count} out-of-office legislators.", {:elapsed_time => Time.now - start}
  end
  
  def self.attributes_from(api_legislator)
    {
      :in_office => api_legislator.in_office,
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
      :first_name => api_legislator.firstname,
      :nickname => api_legislator.nickname,
      :last_name => api_legislator.lastname,
      :state => api_legislator.state,
      :district => api_legislator.district,
      :party => api_legislator.party,
      :title => api_legislator.title,
      :gender => api_legislator.gender,
      :phone => api_legislator.phone,
      :website => api_legislator.website,
      :twitter_id => api_legislator.twitter_id,
      :youtube_url => api_legislator.youtube_url
    }
  end
  
end