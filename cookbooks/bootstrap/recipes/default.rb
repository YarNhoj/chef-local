#
# Cookbook Name:: bootstrap
# Recipe:: default
#
# Copyright (c) 2015 John R. Ray, All Rights Reserved.
# This will install RPMS's and call other cookbooks?
#
#

#Apps
#  Vagrant
#  Virtual Box
#  ChefDk
#  Docker
#  OpenVPN
#  CiscoAnyConnect
#  VSCode
#  google chrome
#
#RPMS
#  wget
#  git
#  curl
#  ansible
#
#System
#  rvm?
#  user creation
#  home directory setup
#  ssh
#  zsh
#  vim
#  tmux

begin
  ga = data_bag_item('apps','global')
  u  = data_bag_item('config', "#{ENV['SUDO_USER']}")
rescue Net::HTTPServerException => e
  Chef::Application.fatal!("#{cookbook_name} could not load data bag; #{e}")
end

ga['packages'].each do |p,v|
  package p do
    action :install
  end
end

home_dir = "/home/#{u['id']}"
group_id = u['id']

ga['apps-ppa'].each do |app,data|

  apt_repository app do
    uri data['uri']
    key data['key']
    distribution node['lsb']['codename']
    components ['contrib']
  end

  package app-"#{data['name']}" do
    action :install
  end

end

ga['apps-remote'].each do |app,data|
  remote_file "#{Chef::Config[:file_cache_path]}/#{app}.deb" do
    source data['url']
    checksum data['checksum']
    notifies :install, 'dpkg_package[app]', :immediately
  end

  dpkg_package app do
    source "#{Chef::Config[:file_cache_path]}/#{app}.deb"
  end

end

user u['id'] do
  comment u['comment']
  uid u['uid']
  gid u['uid']
  home u['home']
  shell u['shell']
  password "#{ENV['USER_PASSWORD']}" || 'changeme'
  action :create
end

if u.has_key?('dirs')
  u['dirs'].each do |dir|
    directory "#{ENV['HOME']}/#{dir}" do
      recursive true
    end
  end
end

if u.has_key?('repos')
  u['repos'].each do |target, repo|
    git "#{ENV['HOME']}/#{target}" do
      repository repo['repo']
      reference repo['revision']
      action :sync
      user u['id']
    end
  end
end

if u.has_key?("ssh_keys")
  directory "#{home_dir}/.ssh" do
    owner u['id']
    group group_id
    mode "0700"
  end

  template "#{home_dir}/.ssh/authorized_keys" do
    source "authorized_keys.erb"
    owner u['id']
    group group_id
    mode "0600"
    variables :ssh_keys => u['ssh_keys']
  end
end

if u.has_key?("files")
  u["files"].each do |filename, file_data|
    directory "#{home_dir}/#{File.dirname(filename)}" do
      recursive true
      mode 0755
    end if file_data['subdir']

    cookbook_file "#{home_dir}/#{filename}" do
      source "#{u['id']}/#{file_data['source']}"
      owner u['id']
      group group_id
      mode file_data['mode']
      ignore_failure true
      backup 0
    end

  end
end
