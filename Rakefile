namespace :sources do

  desc "Run each source's update command"
  task :update => :environment do
    if ENV['source']
      ENV['source'].camelize.constantize.update
    else
      @sources.each do |source|
        source.camelize.constantize.update
      end
    end
  end

end

namespace :entities do

  desc "Run each entity's sync command"
  task :sync => :environment do
    if ENV['entity']
      ENV['entity'].camelize.constantize.sync
    else
      @entities.each do |entity|
        entity.camelize.constantize.sync
      end
    end
  end
  
end

task :environment do
  require 'drumbone'
end