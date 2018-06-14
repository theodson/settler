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
* Postgres 10
* Postgres PGHashLib
* Composer
* Node 9 (Bower, Gulp, Yarn, Grunt)
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
* Laravel Lumen
* Laravel Spark
* Postfix (mail)
* Go Language
* ~~Zend Z-Ray~~


## Build

Run `build.sh`.

# Releases
## 5.2.0
Postgresql-10, Lumen, Spark, Postfix (mail), GoLang, _sendmail_ removed.

## 5.1.0
Node 9, Drush, PGHashLib and Zend Z-Ray (not compatible)

## 5.0.0
using packer php 7.2

## 0.4.4
os updates, better vmware support by adding `config.ssh.password` and `config.ssh.username` to the packaged Vagrant file. 

## 0.4.1
initial attempt to mirror ubuntu homestead (differs with no hhvm and updated postgres to 9.5).  
