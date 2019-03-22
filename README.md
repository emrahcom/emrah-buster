About
=====

`emrah-buster` is an installer to create the containerized systems on Debian
Buster host. It built on top of LXC (Linux containers).

Table of contents
=================

- [About](#about)
- [Usage](#usage)
- [Example](#example)
- [Available templates](#available-templates)
    - [eb-base](#eb-base)
        - [To install eb-base](#to-install-eb-base)
- [Requirements](#requirements)

---

Usage
=====

Download the installer, run it with a template name as an argument and drink a
coffee. That's it.

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/<TEMPLATE_NAME>.conf
bash eb <TEMPLATE_NAME>
```

Example
=======

To install a streaming media system, login a Debian Buster host as `root` and

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb-livestream.conf
bash eb eb-livestream
```

Available templates
===================

eb-base
-------

Install only a containerized Debian Buster.

### To install eb-base

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb-base.conf
bash eb eb-base
```

---

Requirements
============

`emrah-buster` requires a Debian Buster host with a minimal install and
Internet access during the installation. It's not a good idea to use your
desktop machine or an already in-use production server as a host machine.
Please, use one of the followings as a host:

-  a cloud host from a hosting/cloud service
   ([Digital Ocean](https://www.digitalocean.com/?refcode=92b0165840d8)'s
   droplet, [Amazon](https://console.aws.amazon.com) EC2 instance etc)

-  a virtual machine (VMware, VirtualBox etc)

-  a Debian Buster container

-  a physical machine with a fresh installed [Debian Buster](https://www.debian.org/distrib/netinst)
