require 'hpricot'

class Bill
  include MongoMapper::Document
  
  key :govtrack_id, String, :required => true
  key :chamber, String, :required => true
  key :session, String, :required => true
  
  
  timestamps!
  
  
  def self.search_key
    :govtrack_id
  end
  
  def self.fields
    {
      :basic => [:govtrack_id, :type, :session, :chamber, :created_at, :updated_at],
      :info => [:title, :description, :introduced_at, :state],
      :extended => [:summary]
    }
  end
  
  def self.active
    all :conditions => {:session => current_session.to_s}
  end
  
  def self.sync
    session = self.current_session
    
    bills = 0
    
    FileUtils.mkdir_p "data/govtrack/#{session}"
    if system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills.index.xml data/govtrack/#{session}/bills.index.xml")
      
      doc = Hpricot open("data/govtrack/#{session}/bills.index.xml")
      (doc/:bill).each do |b|
        
        type = b.attributes['type']
        number = b.attributes['number']
        govtrack_id = "#{type}#{number}"
        
        if bill = Bill.first(:conditions => {:govtrack_id => govtrack_id})
          puts "[Bill #{bill.govtrack_id}] Updated"
        else
          bill = Bill.new :govtrack_id => govtrack_id
          puts "[Bill #{bill.govtrack_id}] Created"
        end
        
        bill.attributes = {
          :type => type,
          :code => "#{code_for(type)}#{number}",
          :session => session,
          :chamber => chamber_for(type)
        }
        
        bill.save
        bills += 1
      end
      puts "Bills updated for session #{session}: #{bills}"
    else
      puts "Could not rsync to Govtrack.us."
    end
  end
  
  ## helper methods
  
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