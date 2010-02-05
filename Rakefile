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


task :environment do
  require 'drumbone'
end