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

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :migrate do; end
  
  desc "Restart the server"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join current_path, 'tmp', 'restart.txt'}"
  end
  
  desc "Get shared files into position"
  task :after_update_code, :roles => [:web, :app] do
    run "ln -nfs #{shared_path}/config.yml #{release_path}/config.yml"
    run "ln -nfs #{shared_path}/config.ru #{release_path}/config.ru"
    run "rm #{File.join release_path, 'tmp', 'pids'}"
    run "rm #{File.join release_path, 'public', 'system'}"
    run "rm #{File.join release_path, 'log'}"
  end
end