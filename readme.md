# Laravel Settler

The scripts that build the Laravel Homestead development environment. 

End result can be found at https://app.vagrantup.com/laravel/boxes/homestead

## Usage

You probably don't want this repo, follow instructions at https://laravel.com/docs/homestead instead.

If you know what you are doing:

* Clone [chef/bento](https://github.com/chef/bento) into same top level folder as this repo.
* Run `./bin/link-to-bento.sh`
* Run `cd ../bento` and work there for the remainder.
* Follow normal [Packer](https://github.com/chef/bento?tab=readme-ov-file#using-packer) practice of building `os_pkrvars/ubuntu/ubuntu-24.04-*.pkrvars.hcl`

Building on `aarch64`:

```shell
cd <path/to>/bento
packer init -upgrade ./packer_templates
packer build -only=parallels-iso.vm -var-file=os_pkrvars/ubuntu/ubuntu-24.04-aarch64.pkrvars.hcl ./packer_templates
```
Building on `x86-64`:

```shell
cd <path/to>/bento
packer init -upgrade ./packer_templates
packer build -only=virtualbox-iso.vm -var-file=os_pkrvars/ubuntu/ubuntu-24.04-x86_64.pkrvars.hcl ./packer_templates
```

## Apple Silicon

Two commands: build the VM, then package it for the Mac mini fleet.

```shell
SETTLER_VERSION=16.0.0 HOMESTEAD_VERSION=17.0.4 bash bin/build
bash bin/package
```

`bin/package` takes the box `bin/build` just produced, generalizes the guest so
every deployed copy gets its own hostname, machine-id and SSH host keys, and
writes a double-clickable `.vmwarevm` plus a `.dmg` to `dist/`.

Copy the `.dmg` to a Mac mini, open it, and run `Install.command` once per
customer. Fusion on Apple Silicon cannot import OVA/OVF, so this replaces the
old OVA route entirely.

- Building: [docs/build.md](docs/build.md)
- Packaging and distribution: [docs/packaging.md](docs/packaging.md)
