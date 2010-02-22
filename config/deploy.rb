set :environment, (ENV['target'] || 'staging')

set :user, 'drumbone'
set :application, user
set :domain, 'drumbone.sunlightlabs.com'

set :scm, :git
set :repository, "git://github.com/sunlightlabs/#{application}.git"
set :branch, 'master'

set :deploy_to, "/home/#{user}/"
set :deploy_via, :remote_cache
set :runner, user
set :admin_runner, runner

role :app, domain
role :web, domain

set :use_sudo, false
after "deploy", "deploy:cleanup"
after "deploy:update_code", "deploy:shared_links"

desc "Run the update command for a given model"
task :update, :roles => :app, :except => { :no_release => true } do
  if ENV['model']
    run "cd #{current_path} && rake update:manual model=#{ENV['model']}"
  else
    run "cd #{current_path} && rake update:all"
  end
end

namespace :report do
  desc "See reports for a given day (default to last night)"
  task :daily, :roles => :app, :except => {:no_release => true} do
    command = "cd #{current_path} && rake report:daily"
    command += " day=\"#{ENV['day']}\"" if ENV['day']
    run command
  end
  
  desc "See latest failed reports (defaults to 5)"
  task :failure, :roles => :app, :except => {:no_release => true} do
    command = "cd #{current_path} && rake report:failure"
    command += " n=#{ENV['n']}" if ENV['n']
    run command
  end
end

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :migrate do; end
  
  desc "Restart the server"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join current_path, 'tmp', 'restart.txt'}"
  end
  
  desc "Get shared files into position"
  task :shared_links, :roles => [:web, :app] do
    run "ln -nfs #{shared_path}/config.yml #{release_path}/config/config.yml"
    run "ln -nfs #{shared_path}/config.ru #{release_path}/config.ru"
    run "ln -nfs #{shared_path}/data #{release_path}/data"
    run "rm #{File.join release_path, 'tmp', 'pids'}"
    run "rm #{File.join release_path, 'public', 'system'}"
    run "rm #{File.join release_path, 'log'}"
  end
end