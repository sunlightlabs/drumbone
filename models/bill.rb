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
      :extended => [:summary],
      :sponsorship => [:sponsor, :cosponsors]
    }
  end
  
  def self.active
    
  end
  
  def self.update
    session = Bill.current_session
    count = 0
    missing_ids = []
    
    if system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills/ data/govtrack/#{session}/bills/")
      Dir.glob("data/govtrack/#{session}/bills/*.xml").each do |path|
        doc = Hpricot open(path)
        
        type = doc.root.attributes['type']
        number = doc.root.attributes['number']
        govtrack_id = "#{type}#{number}"
        
        if bill = Bill.first(:conditions => {:govtrack_id => govtrack_id})
          # puts "[Bill #{bill.govtrack_id}] Updated"
        else
          bill = Bill.new :govtrack_id => govtrack_id
          # puts "[Bill #{bill.govtrack_id}] Created"
        end
        
        bill.attributes = {
          :type => type,
          :code => "#{code_for(type)}#{number}",
          :session => session,
          :chamber => chamber_for(type),
          :state => doc.at(:state).inner_text,
          :introduced_at => Time.at(doc.at(:introduced)['date'].to_i),
          :title => title_for(doc),
          :description => description_for(doc),
          :summary => doc.at(:summary).inner_text,
          :sponsor => sponsor_for(doc, missing_ids),
          :cosponsors => cosponsors_for(doc, missing_ids)
        }
        
        bill.save
        
        count += 1
      end
      
      Report.success self, "Synced #{count} bills for session ##{session} from GovTrack.us."
      if missing_ids.any?
        missing_ids = missing_ids.uniq
        Report.warning self, "Found #{missing_ids.size} missing GovTrack IDs, attached.", missing_ids
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
  
  def self.format_time(time)
    time.strftime "%Y/%m/%d %H:%M:%S %z"
  end
  
  def self.title_for(doc)
    titles = doc.search "//title[@type='short']"
    titles.any? ? titles.last.inner_text : nil
  end
  
  def self.description_for(doc)
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