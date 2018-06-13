# Laravel Settler `CentOS 7`

These scripts have been modified to enable the use of __CentOS 7__ to host a Laravel application, mirroring Homestead feature for feature.

Due to some Ubuntu specific dependencies (commands and paths) in the Homestead project this isn't easily achieved.
Most dependencies are addressed where possible, some however are not, see Included Software below.

## Included Software

* CentOS 7.5
* Git
* PHP 7.2
* ~~HHVM~~
* Nginx
* MySQL
* ~~MariaDB~~
* Sqlite3
* Postgres 9.5
* Composer
* Node 8 (Bower, Gulp, Yarn, Grunt)
* Redis
* Memcached
* Beanstalkd
* Blackfire
* Mailhog
* Ngrok
* Flyway
* wp_cli
* oh_my_zsh
* Browsershot dependencies (via puppeteer)
* Drush
* ~~Zend Z-Ray~~


## Build

Run `build.sh`.

# Releases

__5.1.0__ - Drush and Zend Z-Ray (not compatible)

__5.0.0__ - using packer php 7.2

__0.4.4__ - os updates, better vmware support by adding `config.ssh.password` and `config.ssh.username` to the packaged Vagrant file. 

__0.4.1__ - initial attempt to mirror ubuntu homestead (differs with no hhvm and updated postgres to 9.5).  
