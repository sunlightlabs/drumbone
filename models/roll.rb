require 'hpricot'

class Roll
  include MongoMapper::Document
  
  key :roll_id, String, :required => true
  key :chamber, String, :required => true
  key :session, String, :required => true
  
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
    # rolls = rolls.first 20
    # roll_id = "h12-111"
    # rolls = rolls.select {|roll| roll == "data/govtrack/#{session}/rolls/#{roll_id}.xml"
    
    rolls.each do |path|
      doc = Hpricot::XML open(path)
      
      roll_id = File.basename path, '.xml'
      
      if roll = Roll.first(:conditions => {:roll_id => roll_id})
        puts "[Roll #{roll_id}] About to be updated"
      else
        roll = Roll.new :roll_id => roll_id
        puts "[Roll #{roll_id}] About to be created"
      end
      
      chamber = doc.root.attributes['where']
      number = doc.root.attributes['roll']
      
      roll.attributes = {
        :chamber => chamber,
        :number => number,
        :session => session
      }
      roll.save
      
      count += 1
    end
    
    Report.success self, "Synced #{count} roll calls for session ##{session} from GovTrack.us.", {:elapsed_time => Time.now - start}
    
  end
end