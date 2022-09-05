# Platform

## Review of `2022-09-01`
PHP-8.1 is released and included in this build 11.5.0

- tighten/takeout composer global
- postgresql 14 with hashlib and timescaledb
- php-8.0 and php-8.1
- docker-ce and docker-compose
- chrome for dusk tests
- redis 6
- fix letsencrypt certificate issue
- phpunit 5-9


## ReImage Existing OVA 6.1.1 to 11.5.0
These instructions are to rebuild an existing "clean/unused" VM from the `6.1.1` image.
```
    UPGRADE_PACK=full bash ./upgrade-6.1.1-11.5.0.sh
```
This will be used to generate distributable OVA file.

## ReImage Existing OVA 6.1.1 to 11.5.0 `developer vm`
These instructions are to rebuild an existing "clean/unused" VM from the `6.1.1` image.  
It installs additional developer tools, e.g. `docker, php73, php74, mysql80`
```
UPGRADE_PACK=developer bash ./upgrade-6.1.1-11.5.0.sh
```

## Upgrade Existing `in use` VM - 6.1.1 to 11.5.0
These instructions are to upgrade an existing "in-use/production" VM using the `6.1.1` image.

Upgrade tested using `theodson-settler` project and the `upgrade-6.1.1-11.5.0.sh` script.

- Upgrade exists 6.1.1
- Install postgres95 extensions
- Install postgres13 and postgres14 on different port - won't interrupt existing pg95 as default.

##### Prepare for upgrade 
This is done by calling the task directly by passing directly as an argument
```
bash ./upgrade-6.1.1-11.5.0.sh prepare
```

##### Call a "collection" of upgrade tasks using env var `UPGRADE_PACK`
```
UPGRADE_PACK=upgrade bash ./upgrade-6.1.1-11.5.0.sh
```

##### Upgrade and install Postgres databases
This is done by calling the tasks directly by passing directly as an argument
```
bash ./upgrade-6.1.1-11.5.0.sh postgresql95

PGPORT=5436 bash ./upgrade-6.1.1-11.5.0.sh postgresql13
PGPORT=5438 bash ./upgrade-6.1.1-11.5.0.sh postgresql14
```



## Notes

PHP-8.1 released November 2021

As an aside - Zizaco Entrust Auth - Is Not Supported outside of Laravel 5.x

https://laracasts.com/discuss/channels/site-improvements/is-this-zizacoentrust-peimission-package-support-for-laravel-7-or-its-outdated-now

> This package is only supporting until Laravel 5.x.
>
> Laravel already has a build-in system for permissions checks or authorization. They are called policies and gates. You can read more about it in the docs
>
> > Documentation: https://laravel.com/docs/7.x/authorization
>
> There are alternative packages like this one: https://github.com/spatie/laravel-permission



### Review of `2021-02-12`

Upgrade tested using `theodson-settler` project and the `upgrade-6.1.1-11.0.0.sh` script.

From the host log into the VM based on homestead `6.1.1`, copy file to vm and run the upgrade script.

``` 
# copy file to vm and run the upgrade script.
vmtoupdate=192.168.20.15 # ip of your VM
ssh root@$vmtoupdate 'mkdir -p provision'
scp scripts/provision.sh scripts/upgrade-6.1.1-11.0.0.sh root@$vmtoupdate:provision/
ssh root@$vmtoupdate provision/upgrade-6.1.1-11.0.0.sh
```


> What are these pecl packages and are they needed?



# Install PHP 7.3
``` 
No package php73-php-pecl-jsond available.
No package php73-php-pecl-jsond-devel available.
```

# Install PHP 7.4
``` 
No package php74-php-pecl-jsond available.
No package php74-php-pecl-jsond-devel available.
```

# Install PHP 8.0
```
Package php80-php-xmlrpc is obsoleted by php80-php-pecl-xmlrpc, trying to install php80-php-pecl-xmlrpc-1.0.0~rc2-1.el7.remi.x86_64 instead
Package php80-php-json is obsoleted by php80-php-common, trying to install php80-php-common-8.0.2-1.el7.remi.x86_64 instead
Package php80-php-xmlrpc is obsoleted by php80-php-pecl-xmlrpc, trying to install php80-php-pecl-xmlrpc-1.0.0~rc2-1.el7.remi.x86_64 instead

No package php80-php-pecl-jsond available.
No package php80-php-pecl-jsond-devel available.
No package php80-php-pecl-stomp available.
```

# Install Postgresql-11
``` 
install_pghashlib(11) - install pghashlib

old hashlib installer not found..moving on
/tmp ~
Archive:  pghashlib.zip
63179b0b720c00ce6e80a4b976ef5f71f854c571
   creating: pghashlib-master/
  inflating: pghashlib-master/COPYRIGHT  
  inflating: pghashlib-master/Makefile  
  inflating: pghashlib-master/README.rst  
   creating: pghashlib-master/debian/
  inflating: pghashlib-master/debian/changelog  
 extracting: pghashlib-master/debian/compat  
  inflating: pghashlib-master/debian/control  
  inflating: pghashlib-master/debian/control.in  
  inflating: pghashlib-master/debian/copyright  
  inflating: pghashlib-master/debian/pgversions  
 extracting: pghashlib-master/debian/postgresql-hashlib-8.3.docs  
  inflating: pghashlib-master/debian/postgresql-hashlib-8.3.install  
 extracting: pghashlib-master/debian/postgresql-hashlib-8.4.docs  
  inflating: pghashlib-master/debian/postgresql-hashlib-8.4.install  
 extracting: pghashlib-master/debian/postgresql-hashlib-9.0.docs  
  inflating: pghashlib-master/debian/postgresql-hashlib-9.0.install  
 extracting: pghashlib-master/debian/postgresql-hashlib-9.1.docs  
  inflating: pghashlib-master/debian/postgresql-hashlib-9.1.install  
 extracting: pghashlib-master/debian/postgresql-hashlib-9.2.docs  
  inflating: pghashlib-master/debian/postgresql-hashlib-9.2.install  
 extracting: pghashlib-master/debian/postgresql-hashlib-9.3.docs  
  inflating: pghashlib-master/debian/postgresql-hashlib-9.3.install  
 extracting: pghashlib-master/debian/postgresql-hashlib-9.4.docs  
  inflating: pghashlib-master/debian/postgresql-hashlib-9.4.install  
  inflating: pghashlib-master/debian/rules  
   creating: pghashlib-master/debian/source/
 extracting: pghashlib-master/debian/source/format  
  inflating: pghashlib-master/debian/source/options  
  inflating: pghashlib-master/hashlib.control  
   creating: pghashlib-master/sql/
  inflating: pghashlib-master/sql/hashlib--1.0--1.1.sql  
  inflating: pghashlib-master/sql/hashlib--1.0.sql  
  inflating: pghashlib-master/sql/hashlib--1.1.sql  
  inflating: pghashlib-master/sql/hashlib--unpackaged--1.0.sql  
  inflating: pghashlib-master/sql/hashlib--unpackaged--1.1.sql  
  inflating: pghashlib-master/sql/hashlib.sql  
  inflating: pghashlib-master/sql/uninstall_hashlib.sql  
   creating: pghashlib-master/src/
  inflating: pghashlib-master/src/city.c  
  inflating: pghashlib-master/src/city.h  
  inflating: pghashlib-master/src/compat-endian.h  
  inflating: pghashlib-master/src/crc32.c  
  inflating: pghashlib-master/src/inthash.c  
  inflating: pghashlib-master/src/lookup2.c  
  inflating: pghashlib-master/src/lookup3.c  
  inflating: pghashlib-master/src/md5.c  
  inflating: pghashlib-master/src/murmur3.c  
  inflating: pghashlib-master/src/pghashlib.c  
  inflating: pghashlib-master/src/pghashlib.h  
  inflating: pghashlib-master/src/pgsql84.c  
  inflating: pghashlib-master/src/siphash.c  
  inflating: pghashlib-master/src/spooky.c  
   creating: pghashlib-master/test/
   creating: pghashlib-master/test/expected/
  inflating: pghashlib-master/test/expected/test_hash.out  
 extracting: pghashlib-master/test/expected/test_init_ext.out  
 extracting: pghashlib-master/test/expected/test_init_noext.out  
   creating: pghashlib-master/test/sql/
  inflating: pghashlib-master/test/sql/test_hash.sql  
 extracting: pghashlib-master/test/sql/test_init_ext.sql  
 extracting: pghashlib-master/test/sql/test_init_noext.sql  
Loaded plugins: fastestmirror, priorities, show-leaves, upgrade-helper,
              : versionlock
Loading mirror speeds from cached hostfile
 * base: mirror.intergrid.com.au
 * epel: mirror.aarnet.edu.au
 * extras: centos.mirror.serversaustralia.com.au
 * remi-php80: remi.conetix.com.au
 * remi-safe: remi.conetix.com.au
 * updates: centos.mirror.serversaustralia.com.au
Retrieving key from https://packagecloud.io/gpg.key
Importing GPG key 0xEBFF1218:
 Userid     : "packagecloud ops (production key) <ops@packagecloud.io>"
 Fingerprint: 6a03 7bb5 2df7 d46d 99dc 59c1 0166 6247 ebff 1218
 From       : https://packagecloud.io/gpg.key
http://packages.blackfire.io/fedora/7/x86_64/repodata/repomd.xml: [Errno -1] repomd.xml signature could not be verified for blackfire
Trying other mirror.
Resolving Dependencies
--> Running transaction check
---> Package postgresql11-devel.x86_64 0:11.11-1PGDG.rhel7 will be installed
--> Processing Dependency: llvm5.0-devel >= 5.0 for package: postgresql11-devel-11.11-1PGDG.rhel7.x86_64
--> Processing Dependency: llvm-toolset-7-clang >= 4.0.1 for package: postgresql11-devel-11.11-1PGDG.rhel7.x86_64
--> Running transaction check
---> Package llvm5.0-devel.x86_64 0:5.0.1-7.el7 will be installed
--> Processing Dependency: llvm5.0(x86-64) = 5.0.1-7.el7 for package: llvm5.0-devel-5.0.1-7.el7.x86_64
--> Processing Dependency: libLLVM-5.0.so()(64bit) for package: llvm5.0-devel-5.0.1-7.el7.x86_64
--> Processing Dependency: libLTO.so.5()(64bit) for package: llvm5.0-devel-5.0.1-7.el7.x86_64
---> Package postgresql11-devel.x86_64 0:11.11-1PGDG.rhel7 will be installed
--> Processing Dependency: llvm-toolset-7-clang >= 4.0.1 for package: postgresql11-devel-11.11-1PGDG.rhel7.x86_64
--> Running transaction check
---> Package llvm5.0.x86_64 0:5.0.1-7.el7 will be installed
---> Package llvm5.0-libs.x86_64 0:5.0.1-7.el7 will be installed
---> Package postgresql11-devel.x86_64 0:11.11-1PGDG.rhel7 will be installed
--> Processing Dependency: llvm-toolset-7-clang >= 4.0.1 for package: postgresql11-devel-11.11-1PGDG.rhel7.x86_64
--> Finished Dependency Resolution
 You could try using --skip-broken to work around the problem
Error: Package: postgresql11-devel-11.11-1PGDG.rhel7.x86_64 (pgdg11)
           Requires: llvm-toolset-7-clang >= 4.0.1
 You could try running: rpm -Va --nofiles --nodigest
make: pg_config: Command not found
make: Nothing to be done for `install'.
Last login: Mon Feb 15 02:23:13 UTC 2021
Last failed login: Mon Feb 15 12:20:40 UTC 2021 on tty1
There was 1 failed login attempt since the last successful login.

===============
check hashlib is installed using commands

psql -U postgres -c 'CREATE EXTENSION hashlib;'
psql -U postgres -c "select encode(hash128_string('abcdefg', 'murmur3'), 'hex');"
11

configure_postgresql(11) - configure postgresql

Initializing database ... OK

```

this is always an issue even if postgresql-11 is the only upgrade that occurs.

``` 
Error: Package: postgresql11-devel-11.11-1PGDG.rhel7.x86_64 (pgdg11)
           Requires: llvm-toolset-7-clang >= 4.0.1
 You could try using --skip-broken to work around the problem
 You could try running: rpm -Va --nofiles --nodigest
```



# TimescaleDb Postgres Extension

```
yum search 
timescaledb-postgresql-10.x86_64 : An open-source time-series database packaged as a PostgreSQL extension.
timescaledb-postgresql-11.x86_64 : An open-source time-series database packaged as a PostgreSQL extension.
timescaledb-postgresql-12.x86_64 : An open-source time-series database packaged as a PostgreSQL extension.
timescaledb-postgresql-9.6.x86_64 : An open-source time-series database packaged as a PostgreSQL extension.

```

install timescaledb in 11 and 12.

``` 
switch_postgres 11
yum install -y timescaledb-postgresql-11
echo "shared_preload_libraries = 'timescaledb'" >> /var/lib/pgsql/11/data/postgresql.conf
systemctl restart postgresql-11.service 
su postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;'"
```

results
``` 
Dependencies Resolved

================================================================================
 Package                    Arch    Version        Repository              Size
================================================================================
Installing:
 timescaledb-postgresql-11  x86_64  1.7.4-0.el7    timescale_timescaledb  315 k
Installing for dependencies:
 timescaledb-tools          x86_64  0.10.1-0.el7   timescale_timescaledb  6.7 M

Transaction Summary
================================================================================
Install  1 Package (+1 Dependent package)

Total download size: 7.0 M
Installed size: 27 M
Downloading packages:
--------------------------------------------------------------------------------
Total                                              2.6 MB/s | 7.0 MB  00:02     
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : timescaledb-tools-0.10.1-0.el7.x86_64                        1/2 
  Installing : timescaledb-postgresql-11-1.7.4-0.el7.x86_64                 2/2 
Using pg_config located at /usr/pgsql-11/bin/pg_config to finish installation...

TimescaleDB has been installed. You need to update your postgresql.conf file
to load the library by adding 'timescaledb' to your shared_preload_libraries.
The easiest way to do this (and more configuration) is to use timescaledb-tune:

timescaledb-tune --pg-config=/usr/pgsql-11/bin/pg_config

  Verifying  : timescaledb-postgresql-11-1.7.4-0.el7.x86_64                 1/2 
  Verifying  : timescaledb-tools-0.10.1-0.el7.x86_64                        2/2 

Installed:
  timescaledb-postgresql-11.x86_64 0:1.7.4-0.el7                                

Dependency Installed:
  timescaledb-tools.x86_64 0:0.10.1-0.el7                                       

Complete!
New leaves:
  timescaledb-postgresql-11.x86_64
could not change directory to "/root": Permission denied
WARNING:  
WELCOME TO
 _____ _                               _     ____________  
|_   _(_)                             | |    |  _  \ ___ \ 
  | |  _ _ __ ___   ___  ___  ___ __ _| | ___| | | | |_/ / 
  | | | |  _ ` _ \ / _ \/ __|/ __/ _` | |/ _ \ | | | ___ \ 
  | | | | | | | | |  __/\__ \ (_| (_| | |  __/ |/ /| |_/ /
  |_| |_|_| |_| |_|\___||___/\___\__,_|_|\___|___/ \____/
               Running version 1.7.4
For more information on TimescaleDB, please visit the following links:

 1. Getting started: https://docs.timescale.com/getting-started
 2. API reference documentation: https://docs.timescale.com/api
 3. How TimescaleDB is designed: https://docs.timescale.com/introduction/architecture

Note: TimescaleDB collects anonymous reports to better understand and assist our users.
For more information and how to disable, please see our docs https://docs.timescaledb.com/using-timescaledb/telemetry.

```


```
switch_postgres 12
yum install -y timescaledb-postgresql-12
echo "shared_preload_libraries = 'timescaledb'" >> /var/lib/pgsql/12/data/postgresql.conf
systemctl restart postgresql-12.service 
su postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;'"

```

results in
``` 
================================================================================
 Package                    Arch    Version        Repository              Size
================================================================================
Installing:
 timescaledb-postgresql-12  x86_64  1.7.4-0.el7    timescale_timescaledb  316 k

Transaction Summary
================================================================================
Install  1 Package

Total download size: 316 k
Installed size: 5.7 M
Downloading packages:
Running transaction check
Running transaction test


Transaction check error:
  file /usr/lib64/timescaledb/timescaledb-1.7.4.so from install of timescaledb-postgresql-12-1.7.4-0.el7.x86_64 conflicts with file from package timescaledb-postgresql-11-1.7.4-0.el7.x86_64
  file /usr/lib64/timescaledb/timescaledb-tsl-1.7.4.so from install of timescaledb-postgresql-12-1.7.4-0.el7.x86_64 conflicts with file from package timescaledb-postgresql-11-1.7.4-0.el7.x86_64
  file /usr/lib64/timescaledb/timescaledb.so from install of timescaledb-postgresql-12-1.7.4-0.el7.x86_64 conflicts with file from package timescaledb-postgresql-11-1.7.4-0.el7.x86_64

Error Summary
-------------

Job for postgresql-12.service failed because the control process exited with error code. See "systemctl status postgresql-12.service" and "journalctl -xe" for details.
could not change directory to "/root": Permission denied
psql: could not connect to server: No such file or directory
	Is the server running locally and accepting
	connections on Unix domain socket "/var/run/postgresql/.s.PGSQL.5432"?
13
```

and then 
``` 
log_build_meta()

ln: failed to create hard link ‘/etc/homestead_co7’: File exists
```


## yum package versions and upgrades

https://www.endpoint.com/blog/2013/09/27/comparing-installed-rpms-on-two-servers

#### list all packages installed and versions
```
# list all packages installed and versions
rpm -qa --qf '%{NAME}_%{VERSION}\n
```

#### automation using deployer/deployer
```
# automation using deployer/deployer
for host in local_app1.testing; 
do 
    echo -e "\n\n======== $host ========";  
    prov run "rpm -qa --qf '%{NAME}_%{VERSION}\n' | sort" --hosts=$host | grep -v '^=' | tee scratch/rpm-list.$host.txt; 
done

```


### `2020-12-14`
> looks like repos have stabilised and have better consistency across versions

# Install PHP 7.3

```
No package php73-php-pecl-jsond available.
No package php73-php-pecl-jsond-devel available.
```

# Install PHP 7.4

```
No package php74-php-pecl-jsond available.
No package php74-php-pecl-jsond-devel available.
```

# Install PHP 8.0
```
No package php80-php-pecl-jsond available.
No package php80-php-pecl-jsond-devel available.
No package php80-php-pecl-stomp available.
```

![]()
