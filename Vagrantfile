VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Configure The Box
  config.vm.box = 'bento/centos-7.2'
  config.vm.hostname = 'homestead-co7'

  # Don't Replace The Default Key https://github.com/mitchellh/vagrant/pull/4707
  config.ssh.insert_key = false

  if Vagrant.has_plugin?("vagrant-cachier")
    # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
    config.cache.scope = :box
  end

  # Ensure that VMWare Tools recompiles kernel modules
  # when we update the linux images
  $fix_vmware_tools_script = <<SCRIPT
sed -i.bak 's/answer AUTO_KMODS_ENABLED_ANSWER no/answer AUTO_KMODS_ENABLED_ANSWER yes/g' /etc/vmware-tools/locations
sed -i 's/answer AUTO_KMODS_ENABLED no/answer AUTO_KMODS_ENABLED yes/g' /etc/vmware-tools/locations
SCRIPT


  # Order is important (must come after Homestead.configure)
  os_type = ENV['box_os'] ||= "centos"

  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--memory', '2048']
    vb.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
    vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
    vb.gui = true
    vb.linked_clone = false if Vagrant::VERSION =~ /^1.8/

    if (os_type == "centos")
      vb.customize ["modifyvm", :id, "--ostype", "RedHat_64"]
    end
  end

  config.vm.provider :vmware_fusion do |v|
    v.memory = 2048
    v.cpus = 2
    v.guestOS = 'centos-64'
    v.gui = true
    v.linked_clone = false

    if (os_type == "centos")
      v.vmx["guestOS"] = "centos-64"
    end
  end

  # Configure Port Forwarding
  config.vm.network 'forwarded_port', guest: 80, host: 8000, auto_correct: true
  config.vm.network 'forwarded_port', guest: 443, host: 4430, auto_correct: true
  config.vm.network 'forwarded_port', guest: 3306, host: 33060, auto_correct: true
  config.vm.network 'forwarded_port', guest: 5432, host: 54320, auto_correct: true
  config.vm.network 'forwarded_port', guest: 35729, host: 35729, auto_correct: true

  config.vm.synced_folder './', '/vagrant', disabled: true

  # Run The Base Provisioning Script

  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = true
    config.vm.provision 'shell', inline: "sudo yum -y install kernel-devel gcc"
  end

  if (os_type == "centos")
    config.vm.provision 'shell', path: './scripts/update-centos.sh'
    #config.vm.provision "shell", inline: $fix_vmware_tools_script
    config.vm.provision 'shell', path: './scripts/vmware_tools-centos.sh'
    config.vm.provision :reload
    config.vm.provision 'shell', path: './scripts/provision-centos.sh'
  else
    config.vm.provision 'shell', path: './scripts/update.sh'
    config.vm.provision :reload
    config.vm.provision 'shell', path: './scripts/vmware_tools.sh'
    config.vm.provision :reload
    config.vm.provision 'shell', path: './scripts/provision.sh'
  end

end
