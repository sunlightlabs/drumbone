desc "Run each model's update command"
task :update => :environment do
  if ENV['model']
    ENV['model'].camelize.constantize.update
  else
    # written out explicitly because order matters
    [Legislator, Bill].each {|model| model.update}
  end
end

task :environment do
  require 'environment'
end