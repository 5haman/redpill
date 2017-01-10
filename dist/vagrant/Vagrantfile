# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.hostname = 'docker.local'

  #config.vm.box = ""

  config.vm.provider "vmware_fusion" do |provider|
    provider.vmx['memsize'] = 2048
    provider.vmx['numvcpus'] = 4
  end

  # Share my entire home directory, so we can share various things with
  # individual docker containers.
  config.vm.synced_folder ENV['HOME'], '/mnt/home'

  config.vm.provision :shell, inline: <<-SHELL
adduser vagrant docker

echo 'DOCKER_OPTS="-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock"' >> /etc/default/docker
restart docker
  SHELL
end
