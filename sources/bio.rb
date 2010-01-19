class Bio
  
  def self.update
    legislators = Legislator.active
    
    legislators.each do |legislator|
      api_legislator = Sunlight::Legislator.all_where(:bioguide_id => legislator.bioguide_id).first
      legislator.attributes = {
        :first_name => api_legislator.firstname,
        :nickname => api_legislator.nickname,
        :last_name => api_legislator.lastname,
        :state => api_legislator.state,
        :district => api_legislator.district,
        :party => api_legislator.party,
        :title => api_legislator.title,
        :gender => api_legislator.gender,
        :phone => api_legislator.phone,
        :website => api_legislator.website,
        :twitter_id => api_legislator.twitter_id,
        :youtube_url => api_legislator.youtube_url
      }
      puts "Updated bio for legislator #{legislator.bioguide_id}"
      legislator.save
    end
    
    legislators.size
  end
  
end