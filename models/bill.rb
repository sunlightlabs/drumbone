require 'hpricot'

class Bill
  include MongoMapper::Document
  
  key :govtrack_id, String, :required => true
  key :chamber, String, :required => true
  key :session, String, :required => true
  key :state, String, :required => true
  
  ensure_index :govtrack_id
  ensure_index :chamber
  ensure_index :session
  ensure_index :sponsor_id
  ensure_index :cosponsor_ids
  
  timestamps!
  
  
  def self.search_key
    :govtrack_id
  end
  
  def self.fields
    {
      :basic => [:govtrack_id, :type, :session, :chamber, :created_at, :updated_at],
      :info => [:short_title, :official_title, :description, :introduced_at, :state],
      :extended => [:summary],
      :sponsorship => [:sponsor, :cosponsors],
      :sponsorship_ids => [:sponsor_id, :cosponsor_ids]
    }
  end
  
  def self.update
    session = Bill.current_session
    count = 0
    missing_ids = []
    
    if system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills/ data/govtrack/#{session}/bills/")
      bills = Dir.glob "data/govtrack/#{session}/bills/*.xml"
      # bills = bills.first 20
      bills.each do |path|
        doc = Hpricot open(path)
        
        type = doc.root.attributes['type']
        number = doc.root.attributes['number']
        govtrack_id = "#{type}#{number}"
        
        if bill = Bill.first(:conditions => {:govtrack_id => govtrack_id})
          puts "[Bill #{bill.govtrack_id}] About to be updated"
        else
          bill = Bill.new :govtrack_id => govtrack_id
          puts "[Bill #{bill.govtrack_id}] About to be created"
        end
        
        sponsor = sponsor_for doc, missing_ids
        cosponsors = cosponsors_for doc, missing_ids
        
        bill.attributes = {
          :type => type,
          :code => "#{code_for(type)}#{number}",
          :session => session,
          :chamber => chamber_for(type),
          :state => doc.at(:state).inner_text,
          :introduced_at => Time.at(doc.at(:introduced)['date'].to_i),
          :short_title => short_title_for(doc),
          :official_title => official_title_for(doc),
          :summary => doc.at(:summary).inner_text,
          :sponsor => sponsor,
          :sponsor_id => sponsor ? sponsor[:govtrack_id] : nil,
          :cosponsors => cosponsors,
          :cosponsor_ids => cosponsors ? cosponsors.map {|c| c[:govtrack_id]} : nil
        }
        
        bill.save
        
        count += 1
      end
      
      Report.success self, "Synced #{count} bills for session ##{session} from GovTrack.us."
      if missing_ids.any?
        missing_ids = missing_ids.uniq
        Report.warning self, "Found #{missing_ids.size} missing GovTrack IDs, attached.", {:missing_ids => missing_ids}
      end
    else
      Report.failure self, "Couldn't rsync to Govtrack.us."
    end
  end
  
  def self.sponsor_for(doc, missing_ids)
    sponsor = doc.at :sponsor
    sponsor and sponsor['id'] ? legislator_for(sponsor['id'], missing_ids) : nil
  end
  
  def self.cosponsors_for(doc, missing_ids)
    cosponsors = (doc/:cosponsor).map do |cosponsor| 
      cosponsor and cosponsor['id'] ? legislator_for(cosponsor['id'], missing_ids) : nil
    end.compact
    cosponsors.any? ? cosponsors : nil
  end
  
  def self.legislator_for(govtrack_id, missing_ids)
    legislator = Legislator.first :conditions => {:govtrack_id => govtrack_id}, :fields => Legislator.fields[:basic] + Legislator.fields[:bio]
    
    if legislator
      attributes = legislator.attributes
      attributes.delete :_id
      attributes
    else
      # log problem: missing govtrack_id
      # puts "Missing govtrack_id: #{govtrack_id}"
      missing_ids << govtrack_id
      nil
    end
  end
  
  # statistics functions
  
  def self.bills_sponsored(legislator)
    Bill.count :conditions => {
      :sponsor_id => legislator.govtrack_id,
      :chamber => legislator.chamber,
      :session => current_session.to_s,
      :type => {'House' => 'h', 'Senate' => 's'}[legislator.chamber]
    }
  end
  
  def self.bills_cosponsored(legislator)
    Bill.count :conditions => {
      :cosponsor_ids => legislator.govtrack_id,
      :chamber => legislator.chamber,
      :session => current_session.to_s,
      :type => {'House' => 'h', 'Senate' => 's'}[legislator.chamber]
    }
  end
  
  def self.resolutions_sponsored(legislator)
    Bill.count :conditions => {
      :sponsor_id => legislator.govtrack_id,
      :chamber => legislator.chamber,
      :session => current_session.to_s,
      :type => {"$in" => {'House' => ['hc', 'hr', 'hj'], 'Senate' => ['sc', 'sr', 'sj']}[legislator.chamber]}
    }
  end
  
  def self.resolutions_cosponsored(legislator)
    Bill.count :conditions => {
      :cosponsor_ids => legislator.govtrack_id,
      :chamber => legislator.chamber,
      :session => current_session.to_s,
      :type => {"$in" => {'House' => ['hc', 'hr', 'hj'], 'Senate' => ['sc', 'sr', 'sj']}[legislator.chamber]}
    }
  end
  
  def self.format_time(time)
    time.strftime "%Y/%m/%d %H:%M:%S %z"
  end
  
  def self.short_title_for(doc)
    titles = doc.search "//title[@type='short']"
    titles.any? ? titles.last.inner_text : nil
  end
  
  def self.official_title_for(doc)
    titles = doc.search "//title[@type='official']"
    titles.any? ? titles.last.inner_text : nil
  end
  
  def self.current_session
    ((Time.now.year + 1) / 2) - 894
  end
  
  def self.chamber_for(type)
    {
      :h => 'House',
      :hr => 'House',
      :hj => 'House',
      :sj => 'Senate',
      :hc => 'House',
      :s => 'Senate'
    }[type.to_sym] || 'Unknown'
  end
  
  def self.code_for(type)
    {
      :h => 'HR',
      :hr => 'HRES',
      :hj => 'HJRES',
      :sj => 'SJRES',
      :hc => 'HCRES',
      :s => 'S'
    }[type.to_sym] || 'Unknown'
  end
end