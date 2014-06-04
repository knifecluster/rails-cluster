# Encoding: utf-8
#
# Cookbook Name:: rails-stack
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#

# Install the version of ruby specified in attributes/default.rb
include_recipe "rbenv::default"
include_recipe "rbenv::ruby_build"

# Make the selected ruby a global install
rbenv_ruby node['rubyversion'] do
  global true
end

# Install packages required for deployment
include_recipe "git::default"

# Install nodejs since Rails requires JS runtime
include_recipe "nodejs::default"

# Install apache2
include_recipe "apache2::default"

# Grab gem path
ruby_block "Get gem path" do
  block do
    node.default["gem_path"] = `/opt/rbenv/shims/gem environment gemdir |tr -d '\n'`
  end
  action :create
end
  
user 'rails' do
  home '/home/rails'
  action :create
end

# Install packages necessary for passenger
%w(libsqlite3-dev libcurl4-openssl-dev apache2-threaded-dev libapr1-dev libaprutil1-dev).each do |package|
  apt_package package do
  action :install
  end
end

# Install rake and other required gems to build site
gem_package 'rake' do
  action :install
  options('--force')
end

gem_package 'passenger' do
  action :install
end

gem_package 'bundler' do
  action :install
end

include_recipe "rbenv::ohai_plugin"

ohai "reload ohai" do
  action :reload
end

execute "build mod_passenger.so" do
  command "/opt/rbenv/bin/rbenv rehash; /opt/rbenv/shims/passenger-install-apache2-module --auto"
  not_if { ::File.exists?("#{node['gem_path']}/gems/passenger-4.0.44/buildout/apache2/mod_passenger.so")}
end

# Deploy application
application 'rails-example' do
  path '/var/www/rails-apps/rails-example'
  owner 'rails'
  group 'rails'
  repository 'https://github.com/rackops/rails-stack.git'
  revision 'HEAD'
  environment_name 'development'
end

# Use bundler to install application gems on the site
execute '/opt/rbenv/shims/bundle install --deployment' do
  cwd '/var/www/rails-apps/rails-example/current'
  user 'rails'
  not_if 'bundle check', :user => 'rails', :cwd => '/var/www/rails-apps/rails-example/current'
end

# Insert the vhost.conf template
template "/etc/apache2/sites-available/rails-example.conf" do
  source "rails-example.conf.erb"
  mode 0644
  owner "root"
  group "root"
end

link "/etc/apache2/sites-enabled/rails-example.conf" do
  to "/etc/apache2/sites-available/rails-example.conf"
end
