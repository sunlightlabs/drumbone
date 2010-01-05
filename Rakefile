namespace :legislators do

  desc "Load legislators from the Sunlight API"
  task :load => :environment do
    require 'sunlight'
    
    Sunlight::Base.api_key = config[:sunlight_api_key]
    Sunlight::Legislator.all_where(:in_office => 1).each do |legislator|
      Legislator.create(
        :bioguide_id => legislator.bioguide_id,
        :first_name => legislator.firstname,
        :nickname => legislator.nickname,
        :last_name => legislator.lastname,
        :state => legislator.state,
        :party => legislator.party,
        :title => legislator.title
      ).save
    end
  end

end

task :environment do
  require 'drumbone'
end

def config
  @config ||= YAML.load_file 'config.yml'
end