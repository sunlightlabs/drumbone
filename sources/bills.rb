class Bills
  
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
          :summary => doc.at(:summary).inner_text
        }
        
        bill.save
        puts "[Bill #{bill.govtrack_id}] Updated"
      end
      
    else
      puts "Couldn't rsync to Govtrack.us."
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