VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Configure The Box
  config.vm.box = 'bento/centos-7.2'
  config.vm.hostname = 'homestead'

  # Don't Replace The Default Key https://github.com/mitchellh/vagrant/pull/4707
  config.ssh.insert_key = false
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  if Vagrant.has_plugin?("vagrant-cachier")

    # When provisioning using VirtualBox we get an error regarding private network and nfs, this fixes that.
    config.vm.network "private_network", ip: "192.168.66.10"

    # Configure cached packages to be shared between instances of the same base box.
    # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
    config.cache.scope = :box

    # OPTIONAL: If you are using VirtualBox, you might want to use that to enable
    # NFS for shared folders. This is also very useful for vagrant-libvirt if you
    # want bi-directional sync
    config.cache.synced_folder_opts = {
      type: :nfs,
      # The nolock option can be useful for an NFSv3 client that wants to avoid the
      # NLM sideband protocol. Without this option, apt-get might hang if it tries
      # to lock files needed for /var/cache/* operations. All of this can be avoided
      # by using NFSv4 everywhere. Please note that the tcp option is not the default.
      mount_options: ['rw', 'vers=3', 'tcp', 'nolock']

    }
    # For more information please check http://docs.vagrantup.com/v2/synced-folders/basic_usage.html
  end

  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--memory', '2048']
    vb.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
    vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
    vb.gui = true
    vb.linked_clone = false if Vagrant::VERSION =~ /^1.8/
  end

  config.vm.provider :vmware_fusion do |v|
    v.memory = 2048
    v.cpus = 2
    v.gui = true
    v.linked_clone = false
  end


  # Configure Port Forwarding
  #config.vm.network 'forwarded_port', guest: 80, host: 8000
  #config.vm.network 'forwarded_port', guest: 3306, host: 33060
  #config.vm.network 'forwarded_port', guest: 5432, host: 54320
  #config.vm.network 'forwarded_port', guest: 35729, host: 35729

  config.vm.synced_folder './', '/vagrant', disabled: true

  # Run The Base Provisioning Script
  config.vm.provision 'shell', path: './scripts/update.sh'
  config.vm.provision :reload
  config.vm.provision 'shell', path: './scripts/vmware_tools.sh'
  config.vm.provision :reload
  config.vm.provision 'shell', path: './scripts/provision.sh'
end
