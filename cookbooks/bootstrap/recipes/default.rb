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
  u  = data_bag_item('config', Etc.getlogin)
rescue Net::HTTPServerException => e
  Chef::Application.fatal!("#{cookbook_name} could not load data bag; #{e}")
end

ga['packages'].each do |p,v|
  package p do
    action :install
  end
end

u['dirs'].each do |dir|
  directory "#{ENV['HOME']}/#{dir}" do
    recursive true
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
