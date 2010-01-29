require 'hpricot'

class Bill
  include MongoMapper::Document
  
  key :govtrack_id, String, :required => true
  key :type, String, :required => true
  key :code, String, :required => true
  key :chamber, String, :required => true
  key :session, String, :required => true
  key :state, String, :required => true
  
  ensure_index :govtrack_id
  ensure_index :type
  ensure_index :code
  ensure_index :chamber
  ensure_index :session
  ensure_index :introduced_at
  ensure_index :sponsor_id
  ensure_index :cosponsor_ids
  ensure_index :keywords
  ensure_index :last_action_at
  ensure_index :last_vote_at
  ensure_index :signed_at
  ensure_index :enacted_at
  
  timestamps!
  
  
  def self.unique_keys
    [:govtrack_id, :code]
  end
  
  def self.search_keys
    [:sponsor_id, :cosponsor_ids, :chamber]
  end
  
  def self.fields
    {
      :basic => [:govtrack_id, :type, :code, :session, :chamber, :created_at, :updated_at, :state],
      :extended =>  [:short_title, :official_title, :introduced_at, :last_action_at, :last_vote_at, :signed_at, :enacted_at],
      :summary => [:summary],
      :keywords => [:keywords],
      :actions => [:actions],
      :sponsorships => [:sponsor, :cosponsors],
      :sponsorship_ids => [:sponsor_id, :cosponsor_ids]
    }
  end
  
  def self.update
    session = Bill.current_session
    count = 0
    missing_ids = []
    
    start = Time.now
    
    FileUtils.mkdir_p "data/govtrack/#{session}/bills"
    unless system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills/ data/govtrack/#{session}/bills/")
      Report.failure self, "Couldn't rsync to Govtrack.us."
      return
    end
      
    bills = Dir.glob "data/govtrack/#{session}/bills/*.xml"
    
    # debug helpers
    # bills = bills.first 20
    # govtrack_id = "h2997"
    # bills = bills.select {|b| b == "data/govtrack/111/bills/#{govtrack_id}.xml"}
    
    bills.each do |path|
      doc = Hpricot::XML open(path)
      
      type = doc.root.attributes['type']
      number = doc.root.attributes['number']
      govtrack_id = "#{type}#{number}"
      
      if bill = Bill.first(:conditions => {:govtrack_id => govtrack_id})
        # puts "[Bill #{bill.govtrack_id}] About to be updated"
      else
        bill = Bill.new :govtrack_id => govtrack_id
        #puts "[Bill #{bill.govtrack_id}] About to be created"
      end
      
      sponsor = sponsor_for doc, missing_ids
      cosponsors = cosponsors_for doc, missing_ids
      actions = actions_for doc
      
      bill.attributes = {
        :type => type,
        :code => "#{code_for(type)}#{number}",
        :session => session,
        :chamber => chamber_for(type),
        :state => doc.at(:state).inner_text,
        :introduced_at => Time.at(doc.at(:introduced)['date'].to_i),
        :short_title => short_title_for(doc),
        :official_title => official_title_for(doc),
        :keywords => doc.search('//subjects/term').map {|term| term['name']},
        :summary => doc.at(:summary).inner_text,
        :sponsor => sponsor,
        :sponsor_id => sponsor ? sponsor[:govtrack_id] : nil,
        :cosponsors => cosponsors,
        :cosponsor_ids => cosponsors ? cosponsors.map {|c| c[:govtrack_id]} : nil,
        :actions => actions,
        :last_action_at => actions ? actions.last[:acted_at] : nil,
        :last_vote_at => last_vote_at_for(doc),
        :enacted_at => enacted_at_for(doc),
        :signed_at => signed_at_for(doc)
      }
      
      bill.save
      
      count += 1
    end
    
    Report.success self, "Synced #{count} bills for session ##{session} from GovTrack.us.", {:elapsed_time => Time.now - start}
    
    if missing_ids.any?
      missing_ids = missing_ids.uniq
      Report.warning self, "Found #{missing_ids.size} missing GovTrack IDs, attached.", {:missing_ids => missing_ids}
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
  
  def self.actions_for(doc)
    actions = doc.search('//actions/*').reject {|a| a.class == Hpricot::Text}.map do |action|
      {:acted_at => Time.at(action['date'].to_i),
       :text => (action/:text).inner_text,
       :type => action.name  
       }
    end
    actions.any? ? actions : nil
  end
  
  def self.enacted_at_for(doc)
    if enacted = doc.at('//actions/enacted')
      Time.at enacted['date'].to_i
    end
  end
  
  def self.signed_at_for(doc)
    if signed = doc.at('//actions/signed')
      Time.at signed['date'].to_i
    end
  end
  
  def self.last_vote_at_for(doc)
    votes = doc.search '//actions/vote|//actions/vote-aux'
    if votes.any?
      Time.at votes.last['date'].to_i
    end
  end
  
  def self.short_title_for(doc)
    titles = doc.search "//title[@type='short']"
    titles.any? ? titles.last.inner_text : nil
  end
  
  def self.official_title_for(doc)
    titles = doc.search "//title[@type='official']"
    titles.any? ? titles.last.inner_text : nil
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
  
  def self.current_session
    ((Time.now.year + 1) / 2) - 894
  end
  
  def self.chamber_for(type)
    {
      :h => 'house',
      :hr => 'house',
      :hj => 'house',
      :hc => 'house',
      :s => 'senate',
      :sr => 'senate',
      :sj => 'senate',
      :sc => 'senate'
    }[type.to_sym]
  end
  
  def self.code_for(type)
    {
      :h => 'hr',
      :hr => 'hres',
      :hj => 'hjres',
      :hc => 'hcres',
      :s => 's',
      :sr => 'sres',
      :sj => 'sjres',
      :sc => 'scres'
    }[type.to_sym]
  end
end