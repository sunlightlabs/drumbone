# Models must support a couple class level methods:
#
# fields: returns a hash of keys to sections of fields. 
#   :basic must be supported, and should contain all database keys and needed identifiers, including timestamps.
#   
# update: Do whatever you have to do to update the model.

require 'sunlight'
require 'fastercsv'
require 'votesmart'

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
  
  ensure_index "ratings.last_updated"
  
  timestamps!
  
  def self.unique_keys
    [:bioguide_id, :govtrack_id]
  end
  
  def self.basic_fields
    [:last_updated, :bioguide_id, :govtrack_id, :crp_id, :votesmart_id, :chamber, :in_office, :first_name, :nickname, :last_name, :name_suffix, :state, :district, :party, :title, :gender, :phone, :website, :twitter_id, :youtube_url, :congress_office]
  end
  
  def self.update_parties(options = {})
    start = Time.now
    missing_ids = []
    
    last_updated = Time.now
    
    # number of days to cut off past parties
    begin_days = 90 # 3 months
    
    
    # download from party time
    unless options[:skip_download]
      old_dir = Dir.pwd
      FileUtils.mkdir_p "data/partytime"
      Dir.chdir "data/partytime"
      system "rm partytime_dump_all.csv"
      system "wget http://politicalpartytime.org/www/partytime_dump_all.csv"
      Dir.chdir old_dir
    end
    
    # go through the CSV
    parties = {}
    FasterCSV.foreach("data/partytime/partytime_dump_all.csv") do |row|
      crp_ids = row[25]
      next unless crp_ids.present?
      
      crp_ids = crp_ids.split "||"
      
      # only select parties newer than 3 months ago
      timestamp = "#{row[4]} #{row[6]}"
      if Time.parse(timestamp) > begin_days.days.ago
        crp_ids.each do |crp_id|
          parties[crp_id] ||= []
          
          parties[crp_id] << {
            :party_id => row[0],
            :date => row[4],
            :start_time => row[6],
            :type => row[8],
            :venue => row[9],
            :venue_url => row[15],
            :contribution_info => row[17]
          }
        end
      end
    end
    
    # puts "Found parties for #{parties.keys.size} in-office legislators"
    
    
    # go through each in_office legislator by crp_id
    Legislator.all(:in_office => true).each do |legislator|
      if legislator.crp_id.blank?
        missing_ids << legislator.bioguide_id
        next
      end
      
      events = parties[legislator.crp_id] || []
      
      # puts "[#{legislator.bioguide_id}] Updated with #{events.size} parties"
      
      legislator.attributes = {:parties => {:events => events, :last_updated => last_updated}}
      legislator.save!
    end
    
    
    if missing_ids.any?
      Report.warning "Parties", "Missing crp_ids from #{missing_ids.size} legislators, bioguide_ids attached", {:missing_ids => missing_ids}
    end
    
    Report.success "Parties", "Updated recent (> #{begin_days} days) for #{parties.keys.size} in-office legislators", {:elapsed_time => Time.now - start, :crp_ids => parties.keys}
  rescue Exception => ex
    Report.failure "Parties", "Exception while updating party time data, error attached", {:message => ex.message, :backtrace => ex.backtrace}
  end
  
  def self.update_ratings(options = {})
    start = Time.now
    missing_ids = []
    skipped_ids = []
    year = Time.now.year
    
    # generally we're going to do this with a limit, since it takes so long
    legislators = []
    if options[:bioguide_id]
      legislators = [Legislator.first :bioguide_id => options[:bioguide_id]]
    else
      limit = options[:limit] || Legislator.count(:in_office => true)
      legislators = all({
        :in_office => true, 
        :limit => limit, 
        :order => "ratings.last_updated ASC"
      })
    end
    
    last_updated = Time.now
    
    # puts "[National] Loading SIGs..."
    national_categories = VoteSmart::Rating.get_categories['categories']['category']
    national_sigs = national_categories.map do |category|
      begin
        VoteSmart::Rating.get_sig_list(category['categoryId'])['sigs']['sig']
      rescue VoteSmart::RequestFailed
        Report.failure "Ratings", "Connection error when getting national SIG list for interest group ratings, aborting"
        return
      end
    end.flatten
    
    
    legislators.each do |legislator|
      if legislator.votesmart_id.blank?
        missing_ids << legislator.bioguide_id
        next
      end
      
      ratings = {}
      
      # puts "[#{legislator.state}] Loading SIGs..."
      state_categories = VoteSmart::Rating.get_categories legislator.state
      state_sigs = []
      if state_categories['categories']
        state_sigs = state_categories['categories']['category'].map do |category|
          begin
            VoteSmart::Rating.get_sig_list(category['categoryId'], legislator.state)['sigs']['sig']
          rescue VoteSmart::RequestFailed
            Report.failure "Ratings", "Connection error when getting #{legislator.state} state SIG list for interest group ratings, aborting"
            return
          end
        end.flatten
      end
      
      (national_sigs + state_sigs).each do |sig|
        sig_id = sig['sigId']
        name = sig['name']
        
        # puts "[#{legislator.bioguide_id}] Fetching rating for #{name} (#{sig_id})..."
        
        results = nil
        begin
          results = VoteSmart::Rating.get_candidate_rating legislator.votesmart_id, sig_id
        rescue VoteSmart::RequestFailed
          skipped_ids << legislator.bioguide_id
          next
        end
        
        if results and results['candidateRating']
          rating = results['candidateRating']['rating']
          rating = rating.first if rating.is_a?(Array)
          
          if (rating['timespan'] =~ /#{year}/) or (rating['timespan'] =~ /#{year-1}/)
            # puts "\t[#{legislator.bioguide_id}] Storing a rating of #{rating['rating']}"
            
            ratings[sig_id] = {
              :timespan => rating['timespan'],
              :rating => rating['rating'],
              :name => name
            }
          else
            # puts "\t[#{legislator.bioguide_id}] Skipping a rating for #{name} from #{rating['timespan']}"
          end
        end
      end
      
      legislator.attributes = {:ratings => ratings.merge(:last_updated => last_updated)}
      legislator.save!
    end
    
    if skipped_ids.any?
      Report.warning "Ratings", "Skipped ratings data for #{skipped_ids.size} legislators due to VoteSmart connection error", {:skipped_ids => skipped_ids}
    end
    
    if missing_ids.any?
      Report.warning "Ratings", "Missing votesmart_ids from #{missing_ids.size} legislators, bioguide_ids attached", {:missing_ids => missing_ids}
    end
    
    Report.success "Ratings", "Updated interest group ratings for #{limit} in_office legislators", {:elapsed_time => Time.now - start}
  rescue Exception => ex
    Report.failure "Ratings", "Exception while updating interest group ratings, error attached", {:message => ex.message, :backtrace => ex.backtrace}
  end
  
  def self.update_earmarks
    start = Time.now
    
    last_updated = File.read("data/earmarks/earmark_timestamp.txt").strip
    
    results = {}
    totals = {
      'H' => {:amount => 0, :number => 0, :n => 0}, 
      'S' => {:amount => 0, :number => 0, :n => 0}
    }
    
    FasterCSV.foreach("data/earmarks/earmark_totals.csv") do |row|
      fiscal_year = row[0].to_i
      bioguide_id = row[1]
      amount = row[2].to_i
      number = row[3].to_i
      chamber = row[4]
      
      results[bioguide_id] = {
        :total_amount => amount,
        :total_number => number,
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
    
    all.each do |legislator|
      if results[legislator.bioguide_id]
        # puts "[#{legislator.bioguide_id}] Adding earmark data"
        
        legislator.attributes = {
          :earmarks => results[legislator.bioguide_id].merge({
             :average_amount => averages[legislator.chamber.to_sym][:amount],
             :average_number => averages[legislator.chamber.to_sym][:number],
             :last_updated => last_updated
          })
        }
        legislator.save
      end
    end
    
    Report.success "Earmarks", "Updated earmark information for all legislators", {:elapsed_time => Time.now - start}
  rescue Exception => ex
    Report.failure "Earmarks", "Exception while updating earmark data, error attached", {:message => ex.message, :backtrace => ex.backtrace}
  end
  
  def self.update_sponsorships
    start = Time.now
    legislators = all :conditions => {:in_office => true}
    
    results = {}
    totals = {
      :house => {:sponsored => 0, :cosponsored => 0, :sponsored_enacted => 0, :cosponsored_enacted => 0, :n => 0}, 
      :senate => {:sponsored => 0, :cosponsored => 0, :sponsored_enacted => 0, :cosponsored_enacted => 0, :n => 0}
    }
    
    legislators.each do |legislator|
      results[legislator.bioguide_id] = {
        :sponsored => legislator.bills_sponsored,
        :cosponsored => legislator.bills_cosponsored,
        :sponsored_enacted => legislator.bills_sponsored_enacted,
        :cosponsored_enacted => legislator.bills_cosponsored_enacted
      }
      
      chamber = legislator.chamber.downcase.to_sym
      totals[chamber][:sponsored] += results[legislator.bioguide_id][:sponsored]
      totals[chamber][:cosponsored] += results[legislator.bioguide_id][:cosponsored]
      totals[chamber][:sponsored_enacted] += results[legislator.bioguide_id][:sponsored_enacted]
      totals[chamber][:cosponsored_enacted] += results[legislator.bioguide_id][:cosponsored_enacted]
      totals[chamber][:n] += 1
    end
    
    
    averages = {
      :house => {
        :sponsored => (totals[:house][:sponsored].to_f / totals[:house][:n].to_f),
        :cosponsored => (totals[:house][:cosponsored].to_f / totals[:house][:n].to_f),
        :sponsored_enacted => (totals[:house][:sponsored_enacted].to_f / totals[:house][:n].to_f),
        :cosponsored_enacted => (totals[:house][:cosponsored_enacted].to_f / totals[:house][:n].to_f)
      },
      :senate => {
        :sponsored => (totals[:senate][:sponsored].to_f / totals[:senate][:n].to_f),
        :cosponsored => (totals[:senate][:cosponsored].to_f / totals[:senate][:n].to_f),
        :sponsored_enacted => (totals[:senate][:sponsored_enacted].to_f / totals[:senate][:n].to_f),
        :cosponsored_enacted => (totals[:senate][:cosponsored_enacted].to_f / totals[:senate][:n].to_f)
      }
    }
    
    
    legislators.each do |legislator|
      chamber = legislator.chamber.downcase.to_sym
      legislator.attributes = {
        :sponsorships => results[legislator.bioguide_id].merge({
          :average_sponsored => averages[chamber][:sponsored],
          :average_cosponsored => averages[chamber][:cosponsored],
          :average_sponsored_enacted => averages[chamber][:sponsored_enacted],
          :average_cosponsored_enacted => averages[chamber][:cosponsored_enacted]
        })
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
  
  def self.update(options = {})
    update_out_of_office
    
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
  
  
  def self.update_out_of_office
    # puts "Initializing out-of-office legislators..."
    
    start = Time.now
    
    initialized_count = 0
    Sunlight::Legislator.all_where(:in_office => 0).each do |api_legislator|
      if legislator = Legislator.first(:conditions => {:bioguide_id => api_legislator.bioguide_id})
        # puts "[Legislator #{legislator.bioguide_id}] Updated"
      else
        legislator = Legislator.new :bioguide_id => api_legislator.bioguide_id
        # puts "[Legislator #{legislator.bioguide_id}] Created"
      end
      
      legislator.attributes = attributes_from api_legislator
      legislator.save
      
      initialized_count += 1
    end
    
    Report.success self, "Created/updated #{initialized_count} out-of-office legislators.", {:elapsed_time => Time.now - start}
  end
  
  def bills_sponsored
    Bill.bills_sponsored_where bioguide_id
  end
  
  def bills_sponsored_enacted
    Bill.bills_sponsored_where bioguide_id, :enacted => true
  end
  
  def bills_cosponsored
    Bill.bills_cosponsored_where bioguide_id
  end
  
  def bills_cosponsored_enacted
    Bill.bills_cosponsored_where bioguide_id, :enacted => true
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
      :govtrack_id => api_legislator.govtrack_id,
      :votesmart_id => api_legislator.votesmart_id,
      :crp_id => api_legislator.crp_id,
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
      :youtube_url => api_legislator.youtube_url,
      :last_updated => Time.now
    }
  end
  
  # if it's an even year, that's it
  # if it's an odd year, add one
  def self.current_cycle
    year = Time.now.year
    year % 2 == 0 ? year : year + 1
  end
  
end