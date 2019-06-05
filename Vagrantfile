# -*- mode: ruby -*-
# vi: set ft=ruby :

disk = "lfs.vdi"

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "debian/stretch64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder "shared", "/vagrant"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  config.vm.provider "virtualbox" do |vb|
    # Customize the amount of memory on the VM:
    vb.memory = "2048"

    unless File.exist?(disk)
      vb.customize ['createhd', '--filename', disk, '--variant', 'Standard', '--size', 10 * 1024]
    end
    vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', disk]
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL

  config.vm.provision "setup", type: "shell", inline: <<-SHELL
    export LFS=/mnt/lfs

    # install needed host packages
    apt-get update
    apt-get install -y parted build-essential gawk bison
    update-alternatives --set awk /usr/bin/gawk

    # use bash as /bin/sh
    echo "dash dash/sh boolean false" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

    # partition disks
    parted -a optimal -s /dev/sdb -- \
      mklabel gpt \
      mkpart primary 1MiB 3MiB \
      name 1 grub \
      set 1 bios_grub on \
      mkpart primary 3MiB 131MiB \
      name 2 boot \
      set 2 boot on \
      mkpart primary 131MiB 643MiB \
      name 3 swap \
      mkpart primary 643MiB -1MiB

    # create filesystems
    mkfs.ext4 /dev/sdb2
    mkfs.ext4 /dev/sdb4
    mkswap /dev/sdb3

    # setup build user
    groupadd lfs
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    chown lfs $LFS/tools
    chown lfs $LFS/sources
    cp /vagrant/lfs_bash_profile ~lfs/.bash_profile
    cp /vagrant/lfs_bashrc ~lfs/.bashrc
    chown lfs:lfs ~lfs/.bash_profile ~lfs/.bashrc
  SHELL

  config.vm.provision "mount", type: "shell", inline: <<-SHELL
    # mount filesystems
    mkdir -p /mnt/lfs
    mount /dev/sdb4 /mnt/lfs
    mkdir -p /mnt/lfs/boot
    mount /dev/sdb2 /mnt/lfs/boot
    swapon /dev/sdb3
  SHELL

  config.vm.provision "download", type: "shell", inline: <<-SHELL
    export LFS=/mnt/lfs

    # download packages
    mkdir -p $LFS/sources
    chmod a+wt $LFS/sources
    wget --input-file=/vagrant/lfs-8.4-wget-list.txt --continue --directory-prefix=$LFS/sources --progress=dot
    pushd $LFS/sources
    md5sum -c /vagrant/lfs-8.4-md5sums.txt
    if [ $? -ne 0 ]; then echo "MD5 checksums didn't match"; exit 1; fi
    popd
  SHELL

  config.vm.provision "build_tools", type: "shell", inline: <<-SHELL
    export LFS=/mnt/lfs

    # setup tools
    mkdir -p $LFS/tools
    ln -sf $LFS/tools /

    # build tools
    su -c "env -i HOME=/home/lfs TERM=$TERM /vagrant/lfs_build_tools.sh" lfs

    chown -R root:root $LFS/tools
  SHELL
end
