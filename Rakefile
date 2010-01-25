desc "Run each model's update command"
task :update => :environment do
  ENV['model'].camelize.constantize.update
end

task :environment do
  require 'environment'
end