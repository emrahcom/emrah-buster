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
    - [eb-livestream](#eb-livestream)
        - [Main components of eb-livestream](#main-components-of-eb-livestream)
        - [To install eb-livestream](#to-install-eb-livestream)
        - [After install eb-livestream](#after-install-eb-livestream)
        - [Related links to eb-livestream](#related-links-to-eb-livestream)
    - [eb-gogs](#eb-gogs)
        - [Main components of eb-gogs](#main-components-of-eb-gogs)
        - [To install eb-gogs](#to-install-eb-gogs)
        - [After install eb-gogs](#after-install-eb-gogs)
        - [SSL certificate for eb-gogs](#ssl-certificate-for-eb-gogs)
        - [Related links to eb-gogs](#related-links-to-eb-gogs)
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

eb-livestream
-------------

Install a ready-to-use live streaming media system.

### Main components of eb-livestream

-  Nginx server with nginx-rtmp-module as a stream origin.
   It gets the RTMP stream and convert it to HLS and DASH.

-  Nginx server with standart modules as a stream edge.
   It publish the HLS and DASH stream.

-  Web based HLS video player.

-  Web based DASH video player.

### To install eb-livestream

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb-livestream.conf
bash eb eb-livestream
```

### After install eb-livestream

-  `rtmp://<IP_ADDRESS>/livestream/<CHANNEL_NAME>` to push
    an RTMP stream.

-  `http://<IP_ADDRESS>/livestream/hls/<CHANNEL_NAME>/index.m3u8` to pull
   the HLS stream.

-  `http://<IP_ADDRESS>/livestream/dash/<CHANNEL_NAME>/index.mpd` to pull
   the DASH stream.

-  `http://<IP_ADDRESS>/livestream/hlsplayer/<CHANNEL_NAME>` for
   the HLS video player page.

-  `http://<IP_ADDRESS>/livestream/dashplayer/<CHANNEL_NAME>` for
   the DASH video player page.

-  `http://<IP_ADDRESS>:8000/livestream/status` for the RTMP status page.

-  `http://<IP_ADDRESS>:8000/livestream/cloner` for the stream cloner page.
   Thanks to [nejdetckenobi](https://github.com/nejdetckenobi)

### Related links to eb-livestream

-  [nginx-rtmp-module](https://github.com/arut/nginx-rtmp-module)

-  [video.js](https://github.com/videojs/video.js)

-  [videojs-contrib-hls](https://github.com/videojs/videojs-contrib-hls)

-  [dash.js](https://github.com/Dash-Industry-Forum/dash.js/)

---

eb-gogs
--------

Install a ready-to-use self-hosted Git service. Only AMD64 architecture is
supported for this template.

### Main components of eb-gogs

- Gogs
- Git
- Nginx
- MariaDB

### To install eb-gogs

```bash
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb
wget https://raw.githubusercontent.com/emrahcom/emrah-buster/master/installer/eb-gogs.conf
bash eb eb-gogs
```

### After install eb-gogs

-  Access `https://<IP_ADDRESS>/` to finish the installation process. Easy!

-  **Password**: There is no password for the database. So, leave it blank!
   Don't worry, only the local user can connect to the database server.

-  **Domain**: Write your host FQDN or IP address. Examples:   
   *git.mydomain.com*   
   *123.2.3.4*

-  **SSH Port**: Leave the default value which is the SSH port of the
   container.

-  **HTTP Port**: Leave the default value which is the internal port of Gogs
   service.

-  **Application URL**: Write your URL. HTTP and HTTPS are OK. Examples:   
   *https://git.mydomain.com/*    
   *https://123.2.3.4/*

-  The first registered user will be the administrator.


### SSL certificate for eb-gogs

To use Let's Encrypt certificate, connect to eb-gogs container as root and

```bash
FQDN="your.host.fqdn"

certbot certonly --webroot -w /var/www/html -d $FQDN

chmod 750 /etc/letsencrypt/{archive,live}
chown root:ssl-cert /etc/letsencrypt/{archive,live}
mv /etc/ssl/certs/{ssl-eb.pem,ssl-eb.pem.bck}
mv /etc/ssl/private/{ssl-eb.key,ssl-eb.key.bck}
ln -s /etc/letsencrypt/live/$FQDN/fullchain.pem \
    /etc/ssl/certs/ssl-eb.pem
ln -s /etc/letsencrypt/live/$FQDN/privkey.pem \
    /etc/ssl/private/ssl-eb.key

systemctl restart nginx.service
```


### Related links to eb-gogs

- [Gogs](https://gogs.io/)
- [Git](https://git-scm.com/)
- [Nginx](http://nginx.org/)
- [MariaDB](https://mariadb.org/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Certbot](https://certbot.eff.org/)

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

-  a physical machine with a fresh installed
   [Debian Buster](https://www.debian.org/releases/buster/debian-installer/)
