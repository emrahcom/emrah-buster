# -----------------------------------------------------------------------------
# GOGS.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-gogs"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/eb_hosts | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30$(printf %03d ${IP##*.})"
echo GOGS="$IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# -----------------------------------------------------------------------------
# NFTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
nft add element eb-nat tcp2ip { $SSH_PORT : $IP }
nft add element eb-nat tcp2port { $SSH_PORT : 22 }
# public http
nft add element eb-nat tcp2ip { 80 : $IP }
nft add element eb-nat tcp2port { 80 : 80 }
# public https
nft add element eb-nat tcp2ip { 443 : $IP }
nft add element eb-nat tcp2port { 443 : 443 }

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_GOGS" = true ] && exit
cd $BASEDIR/$GIT_LOCAL_DIR/lxc/$MACH

echo
echo "-------------------------- $MACH --------------------------"

# -----------------------------------------------------------------------------
# CONTAINER SETUP
# -----------------------------------------------------------------------------
# remove the old container if exists
set +e
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-destroy -n $MACH
rm -rf /var/lib/lxc/$MACH
sleep 1
set -e

# create the new one
lxc-copy -n eb-stretch -N $MACH -p /var/lib/lxc/

# shared directories
mkdir -p $SHARED/cache
cp -arp $BASEDIR/$GIT_LOCAL_DIR/host/usr/local/eb/cache/stretch_apt_archives \
    $SHARED/cache/

# container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives
sed -i '/\/var\/cache\/apt\/archives/d' /var/lib/lxc/$MACH/config
sed -i '/^lxc\.net\./d' /var/lib/lxc/$MACH/config
sed -i '/^# Network configuration/d' /var/lib/lxc/$MACH/config

cat >> /var/lib/lxc/$MACH/config <<EOF
lxc.mount.entry = $SHARED/cache/stretch_apt_archives \
$ROOTFS/var/cache/apt/archives none bind 0 0

# Network configuration
lxc.net.0.type = veth
lxc.net.0.link = $BRIDGE
lxc.net.0.name = eth0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = $IP/24
lxc.net.0.ipv4.gateway = auto

# Start options
lxc.start.auto = 1
lxc.start.order = 600
lxc.start.delay = 2
lxc.group = eb-group
lxc.group = onboot
EOF

# start container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# update
lxc-attach -n $MACH -- \
    zsh -c \
    "apt $APT_PROXY_OPTION update
     apt $APT_PROXY_OPTION -y full-upgrade"

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     debconf-set-selections <<< \
         'mysql-server mysql-server/root_password password'
     debconf-set-selections <<< \
         'mysql-server mysql-server/root_password_again password'
     apt $APT_PROXY_OPTION -y install mariadb-server"

lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt $APT_PROXY_OPTION -y install ssl-cert ca-certificates certbot
     apt $APT_PROXY_OPTION -y install nginx-extras"

lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt $APT_PROXY_OPTION -y install apt-transport-https gnupg2

     wget -qO - https://dl.packager.io/srv/pkgr/gogs/key | apt-key add -
     wget -O /etc/apt/sources.list.d/gogs.list \
         https://dl.packager.io/srv/pkgr/gogs/pkgr/installer/debian/9.repo

     apt $APT_PROXY_OPTION update
     apt $APT_PROXY_OPTION --install-recommends -y install gogs"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
cp etc/nginx/conf.d/custom.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/conf.d/proxy_buffer.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/conf.d/proxy.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/snippets/eb_ssl.conf $ROOTFS/etc/nginx/snippets/
cp etc/nginx/sites-available/gogs $ROOTFS/etc/nginx/sites-available/
ln -s ../sites-available/gogs $ROOTFS/etc/nginx/sites-enabled/
rm $ROOTFS/etc/nginx/sites-enabled/default

# -----------------------------------------------------------------------------
# GOGS
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- mysql <<EOF
CREATE DATABASE gogs DEFAULT CHARACTER SET utf8;
CREATE USER gogs@localhost IDENTIFIED VIA unix_socket;
GRANT ALL PRIVILEGES on gogs.* to gogs@localhost;
EOF

lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i 's/^\(SSH_PORT\s*=\).*$/\1 $SSH_PORT/' /etc/gogs/conf/app.ini
     sed -i 's/^\(DOMAIN\s*=\).*$/\1 your.domain.name/' /etc/gogs/conf/app.ini
     sed -i 's/^\(ROOT_URL\s*=\).*$/\1 https:\/\/%(DOMAIN)s\//' \
         /etc/gogs/conf/app.ini
     sed -i 's/^\(FORCE_PRIVATE\s*=\).*$/\1 true/' /etc/gogs/conf/app.ini
     sed -i 's/127.0.0.1:3306/\/var\/run\/mysqld\/mysqld.sock/' \
         /etc/gogs/conf/app.ini
     sed -i 's/USER = root/USER = gogs/' /etc/gogs/conf/app.ini"

# -----------------------------------------------------------------------------
# SSL
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "cp -ap /etc/ssl/certs/{ssl-cert-snakeoil.pem,ssl-eb.pem}
     cp -ap /etc/ssl/private/{ssl-cert-snakeoil.key,ssl-eb.key}"

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl restart mariadb.service
lxc-attach -n $MACH -- systemctl restart gogs.service
lxc-attach -n $MACH -- systemctl restart nginx.service

lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
