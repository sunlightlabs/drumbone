desc "Run each model's update command"
task :update => :environment do
  if ENV['model']
    ENV['model'].camelize.constantize.update
  else
    models.each do |model|
      model.camelize.constantize.update
    end
  end
end

task :environment do
  require 'config/environment'
end