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
    day = ENV['day'] || Time.now.strftime("%Y-%m-%d")
    
    start_time = Time.now
    
    start = Time.parse day
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
      api_name = config[:services][:api_name]
      shared_secret = config[:services][:shared_secret]
      
      reports.each do |report|
        begin
          SunlightServices.report(report[:key], report[:method], report[:count], day, api_name, shared_secret)
        rescue Exception => exception
          Report.failure 'Analytics', "Problem filing a report, error and report data attached", {:exception => exception, :report => report, :day => day}
        end
      end
    else
      Report.failure 'Analytics', "Sanity check failed: error calculating hit reports. Reports attached.", {:reports => reports}
    end
    
    Report.success 'Analytics', "Filed #{reports.size} reports for #{day}.", {:elapsed_time => (Time.now - start_time)}
  end
  
end

task :environment do
  require 'drumbone'
end