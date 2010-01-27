desc "Run each model's update command"
task :update => :environment do
  if ENV['model']
    model = ENV['model'].camelize.constantize
    if ENV['command']
      model.send ENV['command']
    else
      model.update
    end
  else
    # written out explicitly because order matters
    Legislator.update
    Bill.update
    
    Legislator.update_statistics
  end
end

task :environment do
  require 'drumbone'
end