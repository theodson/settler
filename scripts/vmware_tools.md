*date* : 2019-05-29  
*purpose* : notes for vmware on guest centos
 
## Vagrant Boxes

To be able to generate VM images compatible with vagrant we cannot rely solely on the OVT packaged VMWare `open-vm-tools`. For a VM to be used with `vagrant`  the VMWare `linux.iso` vmware-tools should be installed (as distributed in Fusion, Workstation, vSphere).

https://blog.centos.org/2019/03/updated-centos-vagrant-images-available-v1902-01/

> 1. Installing *open-vm-tools* is not enough for enabling shared folders with Vagrant’s VMware provider. Please follow the detailed instructions in https://github.com/mvermaes/centos-vmware-tools

The instructions at https://github.com/mvermaes/centos-vmware-tools show open-vm-tools (OVT) being installed first and then vmware-tools (ISO) being installed. This relies on the fact that the open-vm-tools components installed will not be overwritten by the VMWare Tools.

Installing updates for the VMWare FileSystem that Vagrant relies upon.

https://github.com/mvermaes/centos-vmware-tools

```
...
...
The vmxnet driver is no longer supported on kernels 3.3 and greater. Please 
upgrade to a newer virtual NIC. (e.g., vmxnet3 or e1000e)

VMware automatic kernel modules enables automatic building and installation of
VMware kernel modules at boot that are not already present. This feature can
be enabled/disabled by re-running vmware-config-tools.pl.

Would you like to enable VMware automatic kernel modules?
[yes] 
INPUT: [yes]  default


Skipping rebuilding initrd boot image for kernel as no drivers to be included 
in boot image were installed by this installer.

The configuration of VMware Tools 10.3.10 build-12406962 for Linux for this 
running kernel completed successfully.

Found VMware Tools CDROM mounted at /mnt/cdrom. Ejecting device /dev/sr0 ...
Enjoy,
..

```

### macOS VMWare Fusion network drivers

You can try editing the .vmx file and changing from e1000 to vmxnet3. By default Fusion will use e1000, to use vmxnet3 shutdown the VM, add a new adapter, then modify the `.vmx` file.

```
# default and most compatible but with more overhead
ethernet2.virtualDev = "e1000"

# paravirtualised driver - fast
ethernet2.virtualDev = "vmxnet3"

```

https://communities.vmware.com/thread/463728



## vmware in `homestead-co7-6.1.1`

VMWare Tools installed is 

```
vmware-toolbox-cmd -v

10.1.10.63510 (build-6082533)
```

https://github.com/chef/bento/blob/master/_common/vmware.sh





# Linux Guest

### check vmware kernel modules loaded

```
for mod in vmblock vmhgfs vmmemctl vmxnet vmci vsock vmsync pvscsi vmxnet3 vmwsvga vmw_pvscsi vmw_balloon vmw_vmci vmw_vsock; do 
  echo "========== $mod =======";modinfo "${mod}" 2>/dev/null | egrep '^version|^description|^filename|^alias' ; 
done 

```

> Versions with "`-k`" originate from the upstream kernel (**OVT - see below**) and versions without "`-k`" originate from VMware Tools

### discover what package installed a file
 (CentOS 7)
```
yum whatprovides /usr/bin/vmware-toolbox-cmd
yum whatprovides /bin/vmtoolsd
```

### discover what files a package offers

```
rpm -ql open-vm-tools-10.2.5-3.el7.x86_64

```


### show vmware supported virtualisation hardware

[https://www.vmware.com/resources/compatibility](https://www.vmware.com/resources/compatibility/detail.php?deviceCategory=Software&productid=37199&vcl=true&supRel=172,243,295,271,301,272,273,326,327,274,275,348,338,360,276,367,396,398,397,369,408,436,437,427,428,479,478&testConfig=16&supRel=172,243,295,271,301,272,273,326,327,274,275,348,338,360,276,367,396,398,397,369,408,436,437,427,428,479,478&testConfig=16)




# Using Open VM Tools

https://github.com/vmware/open-vm-tools

http://partnerweb.vmware.com/GOSIG/CentOS_7.html#Tools

Although a guest operating system can run without VMware Tools, always run the latest version of VMware Tools in your guest operating systems to access the latest features and updates. You can configure your virtual machine to automatically check for and apply VMware Tools upgrades each time you power on your virtual machines.

https://docs.vmware.com/en/VMware-Tools/10.3.0/com.vmware.vsphere.vmwaretools.doc/GUID-5D9177F3-A098-42F7-B87F-551F61BA434E.html

- How is VMware Tools released?

  **ISOs** (containing installers): These are packaged with the product (e.g. VMWare Fusion) and are installed in a number of ways, depending upon the VMware product and the guest operating system installed in the virtual machine. For more information, see the [Installing VMware Tools ](https://docs.vmware.com/en/VMware-Tools/10.3.0/com.vmware.vsphere.vmwaretools.doc/GUID-D8892B15-73A5-4FCE-AB7D-56C2C90BD951.html#__)section. VMware Tools provides a different ISO file for each type of supported guest operating system: Mac OS X, Windows, Linux, NetWare, Solaris, and FreeBSD.

-  **OSP** - Operating System Specific Packages (**OSPs**): Downloadable binary packages that are built and provided by VMware for particular versions of Linux distributions. OSPs are typically available for ***older releases, such as RHEL 6***. Most current versions of Linux include Open VM Tools, eliminating the need to separately install OSPs. To download OSPs and to find important information and instructions, see [VMware Tools Operating System Specific Packages (OSPs)](https://www.vmware.com/support/packages.html). For a list of supported guest operating systems, see [VMware Compatibility Guide](https://www.vmware.com/resources/compatibility/search.php).

-  **OVT** - open-vm-tools (**OVT**): This is the open source implementation of VMware Tools intended for Linux distribution maintainors and virtual appliance vendors. OVTs are generally included in the current versions of popular Linux distributions, allowing administrators to effortlessly install and update VMware Tools alongside other Linux packages. For more information, see KB [VMware support for Open VM Tools (2073803)]



## Guest Host FileSystem mounting

Two options exist

1.  `vmhgfs` as offered by VMWareTools **ISO**
2.  `fuse.vmhgfs-fuse` as provided by Open VM Tools **OVT**.

> `vmhgfs` is currently the only option to use when relying on Vagrant and Packer (VM build tool).

#### `vmhgfs-fuse` or `vmhgfs` - using open-vm-tools

```
sudo mkdir /mnt/hgfs
```

To mount your shares temporarily run the following command.

```
sudo mount -t fuse.vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other
```

To persist the mount you will need to edit the `/etc/fstab` file. Add the following line

```
.host:/ /mnt/hgfs fuse.vmhgfs-fuse allow_other 0 0
```

https://ericsysmin.com/2017/05/24/allow-hgfs-mount-on-open-vm-tools/





## More Info

##### Installing VMware tools on a virtual machine that supports open-vm-tools (2107676)

https://kb.vmware.com/s/article/2107676



##### How to configure VMware Tools Shared Folders Linux mounts (60262)

https://kb.vmware.com/s/article/60262?lang=en_US



##### How to configure VMware Tools Shared Folders Linux mounts (60262)

https://kb.vmware.com/s/article/60262?lang=en_US



##### Choosing a network adapter for your virtual machine (1001805)

https://kb.vmware.com/s/article/1001805



##### VMware support for Linux inbox VMware drivers (2073804)

https://kb.vmware.com/s/article/2073804


