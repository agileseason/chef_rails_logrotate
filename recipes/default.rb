# frozen_string_literal: true

#
# Cookbook Name:: chef_rails_logrotate
# Recipe:: default
#
# Copyright 2017, YOUR_COMPANY_NAME Sidorov
#
# All rights reserved - Do Not Redistribute
#

app = AppHelpers.new node['app']

defaults = {
  su: "#{app.user} #{app.group}",
  olddir: app.dir(:log_old),
  options: %w[compress missingok delaycompress notifempty dateext],
  frequency: 'daily',
  rotate: 180
}

# ----------------------------------------------------
# app
# ----------------------------------------------------
logs = %W[#{app.env}.log #{app.env}_errors.log] + node['chef_rails_logrotate']['logs']
postrotates = []

logrotate_app app.service(:app) do
  su        defaults[:su]
  olddir    defaults[:olddir]
  options   defaults[:options]
  frequency defaults[:frequency]
  rotate    defaults[:rotate]

  path      logs.map { |logfile| "#{app.dir :log}/#{logfile}" }
  postrotate postrotates
end

# ----------------------------------------------------
# puma
# ----------------------------------------------------
if node['chef_rails_logrotate']['puma']
  logs = %w[puma.stderr.log puma.stdout.log]
  postrotates = [
    # rotate signal to rotate puma logs
    "/bin/kill -HUP $(cat #{app.dir :tmp}/pids/puma.pid 2>/dev/null) 2>/dev/null",
    # upgrade signal to rotate our app logs
    "/etc/init.d/#{app.service :puma} upgrade"
  ]

  logrotate_app app.service(:puma) do
    su        defaults[:su]
    olddir    defaults[:olddir]
    options   defaults[:options]
    frequency defaults[:frequency]
    rotate    defaults[:rotate]

    path      logs.map { |logfile| "#{app.dir :log}/#{logfile}" }
    postrotate postrotates
  end
end

# ----------------------------------------------------
# unicorn
# ----------------------------------------------------
if node['chef_rails_logrotate']['unicorn']
  logs = %w[unicorn.log unicorn.error.log]
  postrotates = [
    # rotate signal to rotate unicorn logs
    "/bin/kill -USR1 $(cat #{app.dir :tmp}/pids/unicorn.pid 2>/dev/null) 2>/dev/null",
    "/etc/init.d/#{app.service :unicorn} upgrade"
  ]

  logrotate_app app.service(:unicorn) do
    su        defaults[:su]
    olddir    defaults[:olddir]
    options   defaults[:options]
    frequency defaults[:frequency]
    rotate    defaults[:rotate]

    path      logs.map { |logfile| "#{app.dir :log}/#{logfile}" }
    postrotate postrotates
  end
end

# ----------------------------------------------------
# sidekiq
# ----------------------------------------------------
if node['chef_rails_logrotate']['sidekiq']
  logs = %w[sidekiq.log]
  postrotates = [
    "/etc/init.d/#{app.service :sidekiq} restart"
  ]

  logrotate_app app.service(:sidekiq) do
    su        defaults[:su]
    olddir    defaults[:olddir]
    options   defaults[:options]
    frequency defaults[:frequency]
    rotate    defaults[:rotate]

    path      logs.map { |logfile| "#{app.dir :log}/#{logfile}" }
    postrotate postrotates
  end
end

# ----------------------------------------------------
# shoryuken
# ----------------------------------------------------
if node['chef_rails_logrotate']['shoryuken']
  logs += %w[shoryuken.log]
  postrotates += [
    "/etc/init.d/#{app.service :shoryuken} restart"
  ]

  logrotate_app app.service(:shoryuken) do
    su        defaults[:su]
    olddir    defaults[:olddir]
    options   defaults[:options]
    frequency defaults[:frequency]
    rotate    defaults[:rotate]

    path      logs.map { |logfile| "#{app.dir :log}/#{logfile}" }
    postrotate postrotates
  end
end

# ----------------------------------------------------
# nginx
# ----------------------------------------------------
if node['chef_rails_logrotate']['nginx']
  logrotate_app app.service(:nginx) do
    su        defaults[:su]
    olddir    defaults[:olddir]
    options   defaults[:options]
    frequency node['chef_rails_logrotate']['nginx_frequency']
    rotate    defaults[:rotate]

    path      "#{app.dir :log}/nginx_*.log"
    prerotate <<-BASH.strip
      for file in `ls #{app.dir :log}/ | grep 'nginx_.*\.log$'`
      do
        chown #{app.user}:#{app.group} "#{app.dir :log}/$file"
      done
    BASH
    postrotate '[ ! -f /var/run/nginx.pid ] || kill -USR1 `cat /var/run/nginx.pid`'
  end
end
