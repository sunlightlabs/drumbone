require 'hpricot'

class Roll
  include MongoMapper::Document
  
  key :roll_id, String, :required => true
  key :chamber, String, :required => true
  key :session, String, :required => true
  key :result, String, :required => true
  
  timestamps!
  
  ensure_index :roll_id
  ensure_index :chamber
  ensure_index :session
  ensure_index :type
  ensure_index :result
  ensure_index :voted_at
  ensure_index :type
  ensure_index :bill_id
  
  def self.unique_keys
    [:roll_id]
  end
  
  def self.search_keys
    [:bill_id, :chamber]
  end
  
  def self.fields
    {
      :basic => [:roll_id, :chamber, :session, :result, :bill_id, :voted_at, :updated_at],
      :extended => [:type, :question, :required, :vote_breakdown],
      :party_breakdown => [:party_vote_breakdown],
      :voter_ids => [:voter_ids],
      :voters => [:voters],
      :bill => [:bill]
    }
  end
  
  def self.voter_fields
    [:first_name, :nickname, :last_name, :name_suffix, :title, :state, :party, :govtrack_id, :bioguide_id]
  end
  
  def self.bill_fields
    Bill.fields[:basic] + Bill.fields[:extended]
  end

  def self.update
    session = Bill.current_session
    count  = 0
    
    start = Time.now
    
    FileUtils.mkdir_p "data/govtrack/#{session}/rolls"
    unless system("rsync -az govtrack.us::govtrackdata/us/#{session}/rolls/ data/govtrack/#{session}/rolls/")
      Report.failure self, "Couldn't rsync to Govtrack.us."
      return
    end
    
    
    # make lookups faster later by caching a hash of legislators from which we can lookup govtrack_ids
    legislators = {}
    Legislator.all(:fields => [:first_name, :nickname, :last_name, :name_suffix, :title, :state, :party, :govtrack_id, :bioguide_id]).each do |legislator|
      legislators[legislator.govtrack_id] = legislator
    end
    
    
    # Debug helpers
    # rolls = Dir.glob "data/govtrack/#{session}/rolls/*.xml"
    rolls = Dir.glob "data/govtrack/#{session}/rolls/h2009-2.xml"
    # rolls = Dir.glob "data/govtrack/#{session}/rolls/s2009-391.xml"
    # rolls = rolls.first 20
    
    rolls.each do |path|
      doc = Hpricot::XML open(path)
      
      roll_id = File.basename path, '.xml'
      
      if roll = Roll.first(:conditions => {:roll_id => roll_id})
        # puts "[Roll #{roll_id}] About to be updated"
      else
        roll = Roll.new :roll_id => roll_id
        # puts "[Roll #{roll_id}] About to be created"
      end
      
      bill_id = bill_id_for doc
      voter_ids, voters = votes_for doc, legislators
      party_vote_breakdown = vote_breakdown_for voters
      vote_breakdown = party_vote_breakdown.delete :total
      
      roll.attributes = {
        :chamber => doc.root['where'],
        :session => session,
        :result => doc.at(:result).inner_text,
        :bill_id => bill_id,
        :voted_at => Time.at(doc.root['when'].to_i),
        :type => doc.at(:type).inner_text,
        :question => doc.at(:question).inner_text,
        :required => doc.at(:required).inner_text,
        :bill => bill_for(bill_id),
        :voter_ids => voter_ids,
        :voters => voters,
        :vote_breakdown => vote_breakdown,
        :party_vote_breakdown => party_vote_breakdown
      }
      
      roll.save
      
      count += 1
    end
    
    Report.success self, "Synced #{count} roll calls for session ##{session} from GovTrack.us.", {:elapsed_time => Time.now - start}
    
  end
  
  def self.bill_id_for(doc)
    if bill = doc.at(:bill)
      bill_id = "#{Bill.type_for bill['type']}#{bill['number']}-#{bill['session']}"
    end
  end
  
  def self.bill_for(bill_id)
    bill = Bill.first :conditions => {:bill_id => bill_id}, :fields => bill_fields
    
    if bill
      attributes = bill.attributes
      allowed_keys = bill_fields.map {|f| f.to_s}
      attributes.keys.each {|key| attributes.delete key unless allowed_keys.include?(key)}
      attributes
    else
      nil
    end
  end
  
  def self.vote_breakdown_for(voters)
    breakdown = {}
    mapping = {'-' => :nays, '+' => :ayes, '0' => :not_voting, 'P' => :present}
    
    # keep a tally for every party, and the total
    parties = voters.map {|v| v[:voter]['party']}.uniq + [:total]
    
    voters.each do |voter|
      unless mapping[voter[:vote]]
        mapping[voter[:vote]] = voter[:vote]
      end
    end
    
    parties.each do |party| 
      breakdown[party] = {}
      mapping.values.each do |value|
        breakdown[party][value] = 0
      end
    end
    
    voters.each do|voter|      
      party = voter[:voter]['party']
      vote = mapping[voter[:vote]]
      
      breakdown[party][vote] += 1
      breakdown[:total][vote] += 1
    end
    
    breakdown
  end
  
  def self.votes_for(doc, legislators)
    voter_ids = []
    voters = []
    
    doc.search("//voter").each do |elem|
      vote = elem['vote']
      value = elem['value']
      govtrack_id = elem['id']
      voter = voter_for govtrack_id, legislators
      
      voter_ids << {:vote => vote, :voter_id => voter[:bioguide_id]}
      voters << {:vote => vote, :voter => voter}
    end
    
    [voter_ids, voters.compact]
  end
  
  def self.voter_for(govtrack_id, legislators)
    legislator = legislators[govtrack_id]
    
    if legislator
      attributes = legislator.attributes
      allowed_keys = voter_fields.map {|f| f.to_s}
      attributes.keys.each {|key| attributes.delete key unless allowed_keys.include?(key)}
      attributes
    else
      nil
    end
  end
end