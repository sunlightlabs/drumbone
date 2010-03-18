# Models must support a couple class level methods:
#
# fields: returns a hash of keys to sections of fields. 
#   :basic must be supported, and should contain all database keys and needed identifiers, including timestamps.
#   
# update: Do whatever you have to do to update the model.

require 'sunlight'
require 'fastercsv'

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
  
  def self.basic_fields
    [:updated_at, :bioguide_id, :govtrack_id, :chamber, :in_office, :first_name, :nickname, :last_name, :name_suffix, :state, :district, :party, :title, :gender, :phone, :website, :twitter_id, :youtube_url, :congress_office]
  end
  
  def self.update_earmarks
    start = Time.now
    
    results = {}
    totals = {
      'H' => {:amount => 0, :number => 0, :n => 0}, 
      'S' => {:amount => 0, :number => 0, :n => 0}
    }
    
    FasterCSV.foreach("data/earmarks/earmark_totals.csv") do |row|
      fiscal_year = row[0]
      rank = row[1]
      crp_id = row[2]
      amount = row[3].to_i
      chamber = row[4]
      number = row[5].to_i
      
      results[crp_id] = {
        :total_amount => amount,
        :total_number => number,
        :rank => rank,
        :fiscal_year => fiscal_year
      }
      
      totals[chamber][:amount] += amount
      totals[chamber][:number] += number
      totals[chamber][:n] += 1
    end
    
    averages = {
      :house => {
        :amount => (totals['H'][:amount].to_f / totals['H'][:n].to_f).to_i,
        :number => (totals['H'][:number].to_f / totals['H'][:n].to_f).to_i
      },
      :senate => {
        :amount => (totals['S'][:amount].to_f / totals['S'][:n].to_f).to_i,
        :number => (totals['S'][:number].to_f / totals['S'][:n].to_f).to_i
      }
    }
    
    all(:conditions => {:in_office => true}).each do |legislator|
      if results[legislator.crp_id]
        legislator.attributes = {
          :earmarks => results[legislator.crp_id].merge({
             :average_amount => averages[legislator.chamber.to_sym][:amount],
             :average_number => averages[legislator.chamber.to_sym][:number]
          })
        }
        legislator.save
      end
    end
    
    Report.success "Earmarks", "Updated earmark information for all active legislators", {:elapsed_time => Time.now - start}
  end
  
  def self.update_sponsorships
    start = Time.now
    legislators = all :conditions => {:in_office => true}
    
    legislators.each do |legislator|
      legislator.attributes = {
        :sponsorships => {
          :introduced => legislator.bills_sponsored,
          :passed_house => legislator.bills_sponsored_passed_house,
          :passed_senate => legislator.bills_sponsored_passed_senate,
          :enacted => legislator.bills_sponsored_enacted
        }
      }
      legislator.save
    end
    
    Report.success "Sponsorships", "Updated bill sponsorship stats for all active legislators", {:elapsed_time => Time.now - start}
  end
  
  def self.update_contracts
    fiscal_year = Time.now.year - 1
    start_time = Time.now
    
    count = 0
    
    representatives = Legislator.all :conditions => {:chamber => 'house', :in_office => true}
    senators = Legislator.all :conditions => {:chamber => 'senate', :in_office => true}
    
    states = MongoMapper.database.collection(:legislators).distinct :state
    state_info = {}
    
    states.each do |state|
      # puts "[#{state}] Storing contractor totals"
      
      state_info[state] = UsaSpending.top_contractors_for_state fiscal_year, state
    end
    
    senators.each do |senator|
      # puts "[#{senator.bioguide_id}] Updating contracts for #{senator.title}. #{senator.last_name}"
      
      senator.attributes = {
        :contracts => state_info[senator.state].merge(:fiscal_year => fiscal_year)
      }
      
      senator.save
      count += 1
    end
    
    representatives.each do |representative|
      # puts "[#{representative.bioguide_id}] Updating contracts for #{representative.title}. #{representative.last_name}"
      
      info = UsaSpending.top_contractors_for_district fiscal_year, representative.state, representative.district
      representative.attributes = {
        :contracts => info.merge(:fiscal_year => fiscal_year)
      }
      
      representative.save
      count += 1
    end
    
    Report.success "Contracts", "Updated #{count} legislators with contract data from USASpending.gov", {:elapsed_time => Time.now - start_time}
  rescue Exception => ex
    Report.failure "Contracts", "Exception while fetching contract data from USASpending.gov, error attached", {:message => ex.message, :backtrace => ex.backtrace}
  end
  
  def self.update
    initialize if Legislator.count == 0
    
    active_count = 0
    inactive_count = 0
    bad_legislators = []
    
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
      
      if legislator.save
        active_count += 1
      else
        bad_legislators << {:attributes => legislator.attributes, :error_messages => legislator.errors.full_messages}
      end
    end
    
    old_legislators.each do |legislator|
      legislator.update_attributes :in_office => false
      # puts "[Legislator #{legislator.bioguide_id}] Marked Inactive"
      inactive_count += 1
    end
    
    Report.success self, "Created/updated #{active_count} active legislators, marked #{inactive_count} as inactive", {:elapsed_time => Time.now - start}
    
    if bad_legislators.any?
      Report.failure self, "Failed to save #{bad_legislators.size} legislators. Attached the last failed legislator's attributes and error messages.", bad_legislators.last
    end
    
    active_count + inactive_count
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
  
  def bills_sponsored
    Bill.bills_sponsored_where bioguide_id
  end
  
  def bills_sponsored_passed_house
    Bill.bills_sponsored_where bioguide_id, :house_result => 'pass'
  end
  
  def bills_sponsored_passed_senate
    Bill.bills_sponsored_where bioguide_id, :senate_result => 'pass'
  end
  
  def bills_sponsored_enacted
    Bill.bills_sponsored_where bioguide_id, :enacted => true
  end
  
  def self.attributes_from(api_legislator)
    {
      :in_office => api_legislator.in_office,
      :chamber => {
          'Rep' => 'house',
          'Sen' => 'senate',
          'Del' => 'house',
          'Com' => 'house'
        }[api_legislator.title],
      
      :crp_id => api_legislator.crp_id,
      :govtrack_id => api_legislator.govtrack_id,
      :votesmart_id => api_legislator.votesmart_id,
      :fec_id => api_legislator.fec_id,
      :first_name => api_legislator.firstname,
      :nickname => api_legislator.nickname,
      :last_name => api_legislator.lastname,
      :name_suffix => api_legislator.name_suffix,
      :state => api_legislator.state,
      :district => api_legislator.district,
      :party => api_legislator.party,
      :title => api_legislator.title,
      :gender => api_legislator.gender,
      :phone => api_legislator.phone,
      :website => api_legislator.website,
      :congress_office => api_legislator.congress_office,
      :twitter_id => api_legislator.twitter_id,
      :youtube_url => api_legislator.youtube_url
    }
  end
  
end