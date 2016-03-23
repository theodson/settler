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
* Node 5 (Bower and Gulp)
* Redis
* Memcached
* Beanstalkd

## Build

Add `alias vagrant='HOMESTEADVM='\''centos'\'' vagrant' ` to you host aliases file to allow the build script to choose 
appropriate provisioning files.

# Releases

__0.1__ - initial attempt to mirror ubuntu homestead (differs with no hhvm and updated postgres to 9.5).