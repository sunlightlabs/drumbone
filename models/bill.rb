require 'hpricot'

class Bill
  include MongoMapper::Document
  
  key :bill_id, String, :required => true
  key :type, String, :required => true
  key :code, String, :required => true
  key :chamber, String, :required => true
  key :session, String, :required => true
  key :state, String, :required => true
  
  ensure_index :bill_id
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
  ensure_index :enacted_at
  ensure_index :enacted
  
  timestamps!
  
  
  def self.unique_keys
    [:bill_id]
  end
  
  def self.search_keys
    [:sponsor_id, :cosponsor_ids, :chamber, :enacted]
  end
  
  def self.fields
    {
      :basic => [:bill_id, :type, :code, :number, :session, :chamber, :updated_at, :state, :enacted],
      :extended =>  [:short_title, :official_title, :introduced_at, :last_action_at, :enacted_at, :sponsor_id, :cosponsors_count, :last_vote_at, :votes_count],
      :summary => [:summary],
      :keywords => [:keywords],
      :actions => [:actions],
      :last_action => [:last_action],
      :sponsor => [:sponsor],
      :cosponsors => [:cosponsors],
      :cosponsor_ids => [:cosponsor_ids],
      :votes => [:votes]
    }
  end
  
  def self.sponsor_fields
    [:first_name, :nickname, :last_name, :name_suffix, :title, :state, :party, :district, :govtrack_id, :bioguide_id]
  end
  
  def self.update
    session = Bill.current_session
    count = 0
    missing_ids = []
    bad_bills = []
    
    start = Time.now
    
    FileUtils.mkdir_p "data/govtrack/#{session}/bills"
    unless system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills/ data/govtrack/#{session}/bills/")
      Report.failure self, "Couldn't rsync to Govtrack.us."
      return
    end
    
    # make lookups faster later by caching a hash of legislators from which we can lookup govtrack_ids
    legislators = {}
    Legislator.all(:fields => sponsor_fields).each do |legislator|
      legislators[legislator.govtrack_id] = legislator
    end
    
    
    
    bills = Dir.glob "data/govtrack/#{session}/bills/*.xml"
    # bills = Dir.glob "data/govtrack/#{session}/bills/h730.xml"
    
    # debug helpers
    # bills = bills.first 20
    
    bills.each do |path|
      doc = Hpricot::XML open(path)
      
      type = type_for doc.root.attributes['type']
      number = doc.root.attributes['number']
      code = "#{type}#{number}"
      
      bill_id = "#{code}-#{session}"
      
      if bill = Bill.first(:conditions => {:bill_id => bill_id})
        # puts "[Bill #{bill.bill_id}] About to be updated"
      else
        bill = Bill.new :bill_id => bill_id
        # puts "[Bill #{bill.bill_id}] About to be created"
      end
      
      sponsor = sponsor_for doc, legislators, missing_ids
      cosponsors = cosponsors_for doc, legislators, missing_ids
      actions = actions_for doc
      
      enacted_at = enacted_at_for doc
      
      bill.attributes = {
        :type => type,
        :number => number,
        :code => code,
        :session => session,
        :chamber => {'h' => 'house', 's' => 'senate'}[type.first.downcase],
        :state => doc.at(:state).inner_text,
        :introduced_at => Time.parse(doc.at(:introduced)['datetime']),
        :short_title => short_title_for(doc),
        :official_title => official_title_for(doc),
        :keywords => doc.search('//subjects/term').map {|term| term['name']},
        :summary => summary_for(doc),
        :sponsor => sponsor,
        :sponsor_id => sponsor ? sponsor[:bioguide_id] : nil,
        :cosponsors => cosponsors,
        :cosponsor_ids => cosponsors ? cosponsors.map {|c| c[:bioguide_id]} : nil,
        :cosponsors_count => cosponsors ? cosponsors.size : 0,
        :actions => actions,
        :last_action => actions.last,
        :last_action_at => actions.last ? actions.last[:acted_at] : nil,
        :enacted_at => enacted_at,
        :enacted => !enacted_at.nil?,
        :votes => voice_votes_for(doc)
      }
      
      if bill.save
        count += 1
      else
        bad_bills << {:attributes => bill.attributes, :error_messages => bill.errors.full_messages}
      end
    end
    
    Report.success self, "Synced #{count} bills for session ##{session} from GovTrack.us.", {:elapsed_time => Time.now - start}
    
    if missing_ids.any?
      missing_ids = missing_ids.uniq
      Report.warning self, "Found #{missing_ids.size} missing GovTrack IDs, attached.", {:missing_ids => missing_ids}
    end
    
    if bad_bills.any?
      Report.failure self, "Failed to save #{bad_bills.size} bills. Attached the last failed bill's attributes and errors.", bad_bills.last
    end
    
    count
  end
  
  # This method is going to get run *after* Bill.update and Roll.update
  # In Bill.update, we set aside the voice votes present in the bill's actions
  # into the Bill's "votes" field. This method is meant to take the roll call votes
  # we picked up in Roll.update and integrate them alongside those voice votes,
  # in order of the vote timestamp.
  # 
  # In case you're wondering, we don't pick up all roll call votes when we first process
  # the action list, because not all roll call votes are linked through those actions.
  # Some are, but many are just described in the text and there is no identifier or way of
  # referring consistently to the roll call vote taken. The roll call XML files, on the other
  # hand, consistently reference the bill they are about.
  # 
  # This also sets the last_vote_at timestamp, since we don't know it until we complete
  # this voice/roll-call vote integration process.
  def self.update_votes
    bad_bills = []
    count = 0
    start = Time.now
    
    session = current_session
    
    bills = Bill.all :conditions => {:session => current_session.to_s} #, :limit => 20 # debug
    
    bills.each do |bill|
      voice_votes = bill.votes.select {|vote| vote['how'] == 'voice'} # select as a sanity check
      roll_votes = Roll.find_all_by_bill_id(bill.bill_id).map do |roll|
        # using quotes for certain keys for consistency with voice vote keys
        # once pulled from the database
        {'how' => "roll", 'vote' => {
          :chamber => roll.chamber,
          :question => roll.question,
          :type => roll.type,
          'voted_at' => roll.voted_at,
          :result => roll.result,
          :vote_breakdown => roll.vote_breakdown,
          :roll_id => roll.roll_id
        }}
      end
      
      # puts "Updating bill #{bill.bill_id} with #{voice_votes.size} voice votes and #{roll_votes.size} roll call votes."
      
      votes = (voice_votes + roll_votes).sort_by {|v| v['vote']['voted_at']}
      
      bill.attributes = {
        :votes => votes,
        :votes_count => votes.size,
        :last_vote_at => votes.last ? votes.last['vote']['voted_at'] : nil
      }
      
      if bill.save
        count += 1
      else
        bad_bills << {:attributes => bill.attributes, :error_messages => bill.errors.full_messages}
      end
    end
    
    if bad_bills.any?
      Report.failure self, "Failed to save #{bad_bills.size} bills. Attached the last failed bill's attributes and errors.", bad_bills.last
    end
    
    Report.success self, "Updated voice and roll call votes for #{count} bills.", {:elapsed_time => Time.now - start}
    
    count
  end
  
  def self.summary_for(doc)
    summary = doc.at(:summary).inner_text.strip
    summary.present? ? summary : nil
  end
  
  def self.sponsor_for(doc, legislators, missing_ids)
    sponsor = doc.at :sponsor
    sponsor and sponsor['id'] and !sponsor['withdrawn'] ? legislator_for(sponsor['id'], legislators, missing_ids) : nil
  end
  
  def self.cosponsors_for(doc, legislators, missing_ids)
    cosponsors = (doc/:cosponsor).map do |cosponsor| 
      cosponsor and cosponsor['id'] and !cosponsor['withdrawn'] ? legislator_for(cosponsor['id'], legislators, missing_ids) : nil
    end.compact
    cosponsors.any? ? cosponsors : nil
  end
  
  def self.actions_for(doc)
    doc.search('//actions/*').reject {|a| a.class == Hpricot::Text}.map do |action|
      {
        :acted_at => Time.parse(action['datetime']),
        :text => (action/:text).inner_text,
        :type => action.name
      }
    end
  end
  
  def self.voice_votes_for(doc)
    chamber = {'h' => 'house', 's' => 'senate'}
    doc.search('//actions/vote[@how="by voice vote"]|//actions/vote2[@how="by voice vote"]|//actions/vote-aux[@how="by voice vote"]').map do |vote|
      # using strings for certain keys for consistency in comparison later 
      # when they are fetched from the database
      {'how' => 'voice', 'vote' => {
        :result => vote['result'], 
        'voted_at' => Time.parse(vote['datetime']),
        :question => (vote/:text).inner_text,
        :chamber => chamber[vote['where']]
      }}
    end
  end
  
  def self.enacted_at_for(doc)
    if enacted = doc.at('//actions/enacted')
      Time.parse enacted['datetime']
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
  
  def self.legislator_for(govtrack_id, legislators, missing_ids)
    legislator = legislators[govtrack_id]
    
    if legislator
      attributes = legislator.attributes
      allowed_keys = sponsor_fields.map {|f| f.to_s}
      attributes.keys.each {|key| attributes.delete key unless allowed_keys.include?(key)}
      attributes
    else
      missing_ids << govtrack_id if missing_ids
      nil
    end
  end
  
  # statistics functions
  
  def self.bills_sponsored(legislator)
    Bill.count :conditions => {
      :sponsor_id => legislator.bioguide_id,
      :chamber => legislator.chamber.downcase,
      :session => current_session.to_s,
      :type => {'House' => 'hr', 'Senate' => 's'}[legislator.chamber]
    }
  end
  
  def self.bills_cosponsored(legislator)
    Bill.count :conditions => {
      :cosponsor_ids => legislator.bioguide_id,
      :chamber => legislator.chamber.downcase,
      :session => current_session.to_s,
      :type => {'House' => 'hr', 'Senate' => 's'}[legislator.chamber]
    }
  end
  
  def self.resolutions_sponsored(legislator)
    Bill.count :conditions => {
      :sponsor_id => legislator.bioguide_id,
      :chamber => legislator.chamber.downcase,
      :session => current_session.to_s,
      :type => {"$in" => {'House' => ['hcres', 'hres', 'hjres'], 'Senate' => ['scres', 'sres', 'sjres']}[legislator.chamber]}
    }
  end
  
  def self.resolutions_cosponsored(legislator)
    Bill.count :conditions => {
      :cosponsor_ids => legislator.bioguide_id,
      :chamber => legislator.chamber.downcase,
      :session => current_session.to_s,
      :type => {"$in" => {'House' => ['hcres', 'hres', 'hjres'], 'Senate' => ['scres', 'sres', 'sjres']}[legislator.chamber]}
    }
  end
  
  def self.format_time(time)
    time.strftime "%Y/%m/%d %H:%M:%S %z"
  end
  
  def self.current_session
    ((Time.now.year + 1) / 2) - 894
  end
  
  def self.type_for(type)
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