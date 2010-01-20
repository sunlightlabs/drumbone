class Legislation
  
  def self.update
    session = Bill.current_session
    bills = Bill.active
    
    if system("rsync -az govtrack.us::govtrackdata/us/#{session}/bills/ data/govtrack/#{session}/bills/")
      
      bills.each do |bill|
        doc = Hpricot open("data/govtrack/#{session}/bills/#{bill.govtrack_id}.xml")
        
        bill.attributes = {
          :state => doc.at(:state).inner_text,
          :introduced_at => Time.at(doc.at(:introduced)['date'].to_i),
          :title => title_for(doc),
          :description => description_for(doc),
          :summary => doc.at(:summary).inner_text,
          :sponsor => sponsor_for(doc),
          :cosponsors => cosponsors_for(doc)
        }
        
        if bill.save
          puts "[Bill #{bill.govtrack_id}] Updated"
        else
          puts "[Bill #{bill.govtrack_id}] Could not save - #{bill.errors.full_messages.join ','}"
        end
      end
    else
      puts "Couldn't rsync to Govtrack.us."
    end
  end
  
  def self.sponsor_for(doc)
    sponsor = doc.at :sponsor
    sponsor and sponsor['id'] ? legislator_for(sponsor['id']) : nil
  end
  
  def self.cosponsors_for(doc)
    cosponsors = (doc/:cosponsor).map do |cosponsor| 
      cosponsor and cosponsor['id'] ? legislator_for(cosponsor['id']) : nil
    end.compact
    cosponsors.any? ? cosponsors : nil
  end
  
  def self.legislator_for(govtrack_id)
    legislator = Legislator.first :conditions => {:govtrack_id => govtrack_id}, :fields => Legislator.fields[:basic] + Legislator.fields[:bio]
    
    if legislator
      attributes = legislator.attributes
      attributes.delete :_id
      attributes
    else
      # log problem: missing govtrack_id
      puts "Missing govtrack_id: #{govtrack_id}"
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
end