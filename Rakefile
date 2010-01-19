namespace :legislators do

  desc "Run each source's update command"
  task :update => :sync do
    if ENV['source']
      ENV['source'].camelize.constantize.update
    else
      @sources.each do |source|
        source.camelize.constantize.update
      end
    end
  end

  desc "Load legislators from the Sunlight API"
  task :sync => :environment do
    old_legislators = Legislator.active
    
    Sunlight::Legislator.all_where(:in_office => 1).each do |api_legislator|
      if legislator = Legislator.first(:conditions => {:bioguide_id => api_legislator.bioguide_id})
        old_legislators.delete legislator
        puts "[Legislator #{legislator.bioguide_id}] Updated"
      else
        legislator = Legislator.new :bioguide_id => api_legislator.bioguide_id
        puts "[Legislator #{legislator.bioguide_id}] Created"
      end
      
      legislator.attributes = {
        :active => true,
        :chamber => {
            'Rep' => 'House',
            'Sen' => 'Senate',
            'Del' => 'House',
            'Com' => 'House'
          }[api_legislator.title],
        
        :crp_id => api_legislator.crp_id,
        :govtrack_id => api_legislator.govtrack_id,
        :votesmart_id => api_legislator.votesmart_id,
        :fec_id => api_legislator.fec_id,
      }
      
      legislator.save
    end
    
    old_legislators.each do |legislator|
      legislator.update_attribute :active, false
      puts "[Legislator #{legislator.bioguide_id}] Marked Inactive"
    end
  end

end

task :environment do
  require 'drumbone'
end