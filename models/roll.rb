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
#       :vote_ids => [:vote_ids],
#       :votes => [:votes],
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
        :bill => bill_for(bill_id)
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
end