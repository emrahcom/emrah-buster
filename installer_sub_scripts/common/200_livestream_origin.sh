# -----------------------------------------------------------------------------
# LIVESTREAM_ORIGIN.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-livestream-origin"
ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/eb_hosts | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30$(printf %03d ${IP##*.})"
echo LIVESTREAM_ORIGIN="$IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# -----------------------------------------------------------------------------
# NFTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
nft add element eb-nat tcp2ip { $SSH_PORT : $IP }
nft add element eb-nat tcp2port { $SSH_PORT : 22 }
# rtmp push
nft add element eb-nat tcp2ip { 1935 : $IP }
nft add element eb-nat tcp2port { 1935 : 1935 }
# admin web
nft add element eb-nat tcp2ip { 8000 : $IP }
nft add element eb-nat tcp2port { 8000 : 80 }

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_LIVESTREAM_ORIGIN" = true ] && exit
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
lxc-copy -n eb-buster -N $MACH -p /var/lib/lxc/

# shared directories
mkdir -p $SHARED/cache
cp -arp $BASEDIR/$GIT_LOCAL_DIR/host/usr/local/eb/cache/buster_apt_archives \
    $SHARED/cache/
cp -arp $BASEDIR/$GIT_LOCAL_DIR/host/usr/local/eb/livestream $SHARED/

# container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives
rm -rf $ROOTFS/usr/local/eb/livestream
mkdir -p $ROOTFS/usr/local/eb/livestream
sed -i '/\/var\/cache\/apt\/archives/d' /var/lib/lxc/$MACH/config
sed -i '/^lxc\.net\./d' /var/lib/lxc/$MACH/config
sed -i '/^# Network configuration/d' /var/lib/lxc/$MACH/config

cat >> /var/lib/lxc/$MACH/config <<EOF
lxc.mount.entry = $SHARED/cache/buster_apt_archives \
$ROOTFS/var/cache/apt/archives none bind 0 0
lxc.mount.entry = $SHARED/livestream \
$ROOTFS/usr/local/eb/livestream none bind 0 0

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
# multimedia repo
cp etc/apt/sources.list.d/multimedia.list $ROOTFS/etc/apt/sources.list.d/
lxc-attach -n $MACH -- \
    zsh -c \
    "apt $APT_PROXY_OPTION -oAcquire::AllowInsecureRepositories=true update
     sync
     apt $APT_PROXY_OPTION --allow-unauthenticated -y install \
         deb-multimedia-keyring"
# update
lxc-attach -n $MACH -- \
    zsh -c \
    "apt $APT_PROXY_OPTION update
     apt $APT_PROXY_OPTION -y full-upgrade"

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt $APT_PROXY_OPTION -y install xmlstarlet libxml2-utils"
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt $APT_PROXY_OPTION -y install ffmpeg
     apt $APT_PROXY_OPTION -y install nginx libnginx-mod-rtmp
     apt $APT_PROXY_OPTION -y install xz-utils

     mkdir /tmp/source
     cd /tmp/source
     apt $APT_PROXY_OPTION -dy source nginx
     tar xf nginx_*.debian.tar.xz

     mkdir -p /usr/local/eb/livestream/stat/
     cp /tmp/source/debian/modules/rtmp/stat.xsl \
         /usr/local/eb/livestream/stat/rtmp_stat.xsl
     chown www-data: /usr/local/eb/livestream/stat -R"
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt $APT_PROXY_OPTION -y install uwsgi uwsgi-plugin-python3
     apt $APT_PROXY_OPTION --install-recommends -y install python3-pip
     pip3 install --upgrade setuptools
     pip3 install mydaemon
     pip3 install flask"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
rm -rf $ROOTFS/var/www/livestream_cloner
mkdir -p $ROOTFS/var/www/livestream_cloner
rsync -aChu var/www/livestream_cloner/ $ROOTFS/var/www/livestream_cloner/
chown www-data:www-data $ROOTFS/var/www/livestream_cloner -R

cp etc/uwsgi/apps-available/livestream_cloner.ini \
    $ROOTFS/etc/uwsgi/apps-available/
ln -s ../apps-available/livestream_cloner.ini $ROOTFS/etc/uwsgi/apps-enabled/

cp etc/nginx/access_list_http.conf $ROOTFS/etc/nginx/
cp etc/nginx/access_list_rtmp.conf $ROOTFS/etc/nginx/
cp etc/nginx/conf.d/custom.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/modules-available/90-eb-rtmp.conf \
    $ROOTFS/etc/nginx/modules-available/
ln -s ../modules-available/90-eb-rtmp.conf $ROOTFS/etc/nginx/modules-enabled/
cp etc/nginx/sites-available/livestream-origin \
    $ROOTFS/etc/nginx/sites-available/
ln -s ../sites-available/livestream-origin $ROOTFS/etc/nginx/sites-enabled/
rm $ROOTFS/etc/nginx/sites-enabled/default

cp -arp root/eb_scripts/ $ROOTFS/root/
chmod u+x $ROOTFS/root/eb_scripts/*.sh
cp etc/cron.d/eb_livestream_cleanup $ROOTFS/etc/cron.d/

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl restart uwsgi
lxc-attach -n $MACH -- systemctl reload nginx

lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
