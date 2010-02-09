namespace :update do
  
  desc "Run a method on a model (defaults to #update)"
  task :manual => :environment do
    model = ENV['model'].camelize.constantize
    
    if ENV['method']
      model.send ENV['method']
    else
      model.update
    end
  end
  
  desc "Run the suite of updates"
  task :all => :environment do
    Legislator.update
    Bill.update
    Roll.update
    
    Legislator.update_statistics
    Legislator.update_contracts
  end
end

namespace :report do
  
  desc "Report analytics to the central API analytics department."
  task :analytics => :environment do
    if ENV['day']
      start = Time.parse ENV['day']
    else
      start = Time.now.midnight
    end
    
    finish = start + 1.day
    conditions = {:created_at => {"$gte" => start, "$lt" => finish}}
    
    reports = []
    
    # get down to the driver level for the iteration
    hits = MongoMapper.connection.db('drumbone').collection('hits')
    
    keys = hits.distinct :key, conditions
    keys.each do |key|
      methods = hits.distinct :method, conditions.merge(:key => key)
      methods.each do |method|
        count = Hit.count conditions.merge(:key => key, :method => method)
        reports << {:key => key, :method => method, :count => count}
      end
    end
    
    if reports.map {|r| r[:count]}.sum == Hit.count(conditions)
      p reports
    else
      puts "Sanity check failed: error calculating hit report."
    end
  end
  
end

task :environment do
  require 'drumbone'
end