# Laravel Settler

The scripts that build the Laravel Homestead development environment.


End result can be found at https://app.vagrantup.com/laravel/boxes/homestead

## Usage

You probably don't want this repo, follow instructions at https://laravel.com/docs/homestead instead.

If you know what you are doing:

* Clone [chef/bento](https://github.com/chef/bento) into same top level folder as this repo.
* Run `./bin/link-to-bento.sh`
* Run `cd ../bento` and work there for the remainder.
* Follow normal [Packer](https://www.packer.io/) practice of building `ubuntu/ubuntu-20.04-amd64.json`



See [release.md](release.md) for build details.

## Usage

This build tool clones the `bento` git project and inserts the `scripts/provision.sh` file into the packer build sequence. The `bento` project uses the [Vagrant](https://www.vagrant.io/)  teams [Packer](https://www.packer.io/)  tool.

We rely on the `bento` packer project for delivering stable and upto date Virtualized Environments.

### Quick start

* specify version and run `build.sh`


```
VERSION=11.5.0
BENTO_PATH=../bento
git clone https://github.com/chef/bento $BENTO_PATH

./build.sh $VERSION
```


### Custom 
* Review the `scripts/provision.sh` - this runs CentOS build commands. 
* Review in file `./build.sh` as it follows the normal [Packer](https://www.packer.io/) practice of building  with `centos/centos-7.5-x86_64.json`. 
