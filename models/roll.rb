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
      :basic => [:roll_id, :chamber, :session, :result, :bill_id, :voted_at, :created_at, :updated_at],
      :extended => [:type, :question, :required, :ayes, :nays, :not_voting, :present],
      :voter_ids => [:voter_ids],
      :voters => [:voters],
      :bill => [:bill]
    }
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
    
    rolls = Dir.glob "data/govtrack/#{session}/rolls/*.xml"
    
    
    # make lookups faster later by caching a hash of legislators from which we can lookup govtrack_ids
    legislators = {}
    Legislator.all(:fields => [:first_name, :nickname, :last_name, :name_suffix, :title, :govtrack_id, :bioguide_id]).each do |legislator|
      legislators[legislator.govtrack_id] = legislator
    end
    
    
    # Debug helpers
    # rolls = rolls.first 20
    # roll_id = "h2010-22"
    # rolls = rolls.select {|roll| roll == "data/govtrack/#{session}/rolls/#{roll_id}.xml"}
    
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
      
      roll.attributes = {
        :chamber => doc.root['where'],
        :session => session,
        :result => doc.at(:result).inner_text,
        :bill_id => bill_id,
        :voted_at => Time.at(doc.root['when'].to_i),
        :type => doc.at(:type).inner_text,
        :question => doc.at(:question).inner_text,
        :required => doc.at(:required).inner_text,
        :ayes => doc.root['aye'],
        :nays => doc.root['nay'],
        :not_voting => doc.root['nv'],
        :present => doc.root['present'],
        :bill => bill_for(bill_id),
        :voter_ids => voter_ids,
        :voters => voters
      }
      
      roll.save
      
      count += 1
    end
    
    Report.success self, "Synced #{count} roll calls for session ##{session} from GovTrack.us.", {:elapsed_time => Time.now - start}
    
  end
  
  def self.bill_id_for(doc)
    if bill = doc.at(:bill)
      "#{bill['type']}#{bill['number']}-#{bill['session']}"
    end
  end
  
  def self.bill_for(bill_id)
    bill = Bill.first :conditions => {:govtrack_id => bill_id}, :fields => Bill.fields[:basic] + Bill.fields[:extended]
    
    if bill
      attributes = bill.attributes
      attributes.delete :_id
      attributes
    else
      nil
    end
  end
  
  def self.votes_for(doc, legislators)
    voter_ids = []
    voters = []
    
    doc.search("//voter").each do |elem|
      vote = elem['vote']
      value = elem['value']
      govtrack_id = elem['id']
      voter = voter_for govtrack_id, legislators
      
      voter_ids << {:vote => vote, :voter_id => govtrack_id}
      voters << {:vote => vote, :voter => voter}
    end
    
    [voter_ids, voters.compact]
  end
  
  def self.voter_for(govtrack_id, legislators)
    legislator = legislators[govtrack_id]
    
    if legislator
      attributes = legislator.attributes
      [:_id, :created_at, :updated_at, :chamber, :in_office].each {|a| attributes.delete a}
      attributes
    else
      nil
    end
  end
end