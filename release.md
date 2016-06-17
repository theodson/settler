# Laravel Settler `CentOS 7`

These scripts have been modified to enable the use of __CentOS 7__ to host a Laravel application, mirroring Homestead feature for feature.

Due to some Ubuntu specific dependencies (commands and paths) in the Homestead project this isn't easily achieved.
Most dependencies are addressed where possible, some however are not, see Included Software below.

## Included Software

* CentOS 7.2
* Git
* PHP 7.0
* ~~HHVM~~
* Nginx
* MySQL
* ~~MariaDB~~
* Sqlite3
* Postgres 9.5
* Composer
* Node 6 (Bower and Gulp)
* Redis
* Memcached
* Beanstalkd

## Build

Default behaviour is to build against a CentOS specific version, the same can be achieved explicitly with the __box_os__ env variable.

    export box_os='centos'
    vagrant up

To build using the Ubuntu version modify the __box_os__  
appropriate provisioning files.

    export box_os='ubuntu'
    vagrant up


# Releases

__0.4.1__ - initial attempt to mirror ubuntu homestead (differs with no hhvm and updated postgres to 9.5).  
__0.4.4__ - 