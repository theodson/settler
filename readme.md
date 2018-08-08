# Laravel Settler

The scripts that builds a Laravel Homestead development environment using `CentOS`.

See [release.md](release.md) for build details.

## Usage

This build tool clones the `bento` git project and inserts the `scripts/provision.sh` file into the packer build sequence. The `bento` project uses the [Vagrant](https://www.vagrant.io/)  teams [Packer](https://www.packer.io/)  tool.

We rely on the `bento` packer project for delivering stable and upto date Virtualized Environments.

### Quick start

* specify version and run `build.sh`

```
VERSION=6.1.1
./build.sh $VERSION
```


### Custom 
* Review the `scripts/provision.sh` - this runs CentOS build commands. 
* Review in file `./build.sh` as it follows the normal [Packer](https://www.packer.io/) practice of building  with `centos/centos-7.5-x86_64.json`. 
