#
# Cookbook Name:: bootstrap
# Recipe:: default
#
# Copyright (c) 2015 John R. Ray, All Rights Reserved.
# This will install RPMS's and call other cookbooks?
#
#

#Apps
#  CiscoAnyConnect
#  VSCode
#
#System
#  rvm?
#  user creation
#  home directory setup
#  ssh
#  zsh
# vim

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

docker_service 'default' do
  action [:create, :start]
  host [ "tcp://#{node['ipaddress']}:2376", 'unix:///var/run/docker.sock' ]
end

home_dir = "/home/#{u['id']}"
group_id = u['id']

ga['apps-ppa'].each do |app,data|

  apt_repository app do
    uri data['uri']
    key data['key']
    keyserver data['keyserver']
    distribution data['dist']
    components [data['comp']]
  end

  package app do
    action :install
  end

end

ga['apps-remote'].each do |app,data|
  remote_file "#{Chef::Config[:file_cache_path]}/#{app}.deb" do
    source data['url']
    checksum data['checksum']
    notifies :install, "dpkg_package[#{app}]", :immediately
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
  action :create
end

# Install oh my zsh
execute 'omz_install' do
  command 'sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"'
  user 'jray'
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
