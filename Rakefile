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
    
    Legislator.update_sponsorships
    Legislator.update_contracts
    Legislator.update_earmarks
    Legislator.update_ratings :limit => 10
    Legislator.update_parties
  end
end

namespace :development do
  desc "Load a fake 'development' api key into the db"
  task :api_key => :environment do
    
    key = ENV['key'] || "development"
    email = ENV['email'] || "#{key}@example.com"
    
    if ApiKey.where(:key => key).first.nil?
      ApiKey.create! :status => "A", :email => email, :key => key
      puts "Created '#{key}' API key under email #{email}"
    else
      puts "'#{key}' API key already exists"
    end
  end
end

namespace :report do
  
  desc "See reports for a given day (default to last night)"
  task :daily => :environment do
    # default to today (since we run at past midnight)
    day = ENV['day'] || Time.now.midnight.strftime("%Y-%m-%d")
    
    start = Time.parse day
    finish = start + 1.day
    conditions = {:created_at => {"$gte" => start, "$lt" => finish}}
    
    puts "\nReports for #{day}:\n\n"
    
    Report.all(conditions).each do |report|
      puts "#{report}\n\n"
    end
  end
  
  desc "See latest failed reports (defaults to 5)"
  task :failure => :environment do
    limit = ENV['n'] || 5
    
    puts "Latest #{limit} failures:\n\n"
    
    Report.all(:order => "created_at DESC", :limit => 5, :status => "FAILURE").each do |report|
      puts "(#{report.created_at.strftime "%Y-%m-%d"}) #{report}\n\n"
    end
  end
end

namespace :api do
  
  desc "Send analytics to the central API analytics department."
  task :analytics => :environment do
    # default to yesterday
    day = ENV['day'] || (Time.now.midnight - 1.day).strftime("%Y-%m-%d")
    test = !ENV['test'].nil?
    
    start_time = Time.now
    
    start = Time.parse day
    finish = start + 1.day
    conditions = {:created_at => {"$gte" => start, "$lt" => finish}}
    
    reports = []
    
    # get down to the driver level for the iteration
    hits = MongoMapper.database.collection :hits
    
    keys = hits.distinct :key, conditions
    keys.each do |key|
      methods = hits.distinct :method, conditions.merge(:key => key)
      methods.each do |method|
        count = Hit.count conditions.merge(:key => key, :method => method)
        reports << {:key => key, :method => method, :count => count}
      end
    end
    
    sum_count = reports.map {|r| r[:count]}.sum
    hit_count = Hit.count conditions
    if sum_count == hit_count
      api_name = config[:services][:api_name]
      shared_secret = config[:services][:shared_secret]
      
      reports.each do |report|
        begin
          SunlightServices.report(report[:key], report[:method], report[:count], day, api_name, shared_secret) unless test
        rescue Exception => exception
          Report.failure 'Analytics', "Problem filing a report, error and report data attached", {:error_message => exception.message, :backtrace => exception.backtrace, :report => report, :day => day}
        end
      end
      
      if test
        puts "\nWould report for #{day}:\n\n#{reports.inspect}\n\nTotal hits: #{reports.sum {|r| r[:count]}}\n\n"
      else
        Report.success 'Analytics', "Filed #{reports.size} report(s) for #{day}.", {:elapsed_time => (Time.now - start_time)}
      end
    
    else
      Report.failure 'Analytics', "Sanity check failed: error calculating hit reports. Reports attached.", {:reports => reports, :day => day}
      
    end
    
  end
  
end

task :environment do
  require 'rubygems'
  require 'bundler/setup'
  require 'config/environment'
end