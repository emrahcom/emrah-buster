#!/bin/bash

# -----------------------------------------------------------------------------
# NETWORK.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
# public interface
DEFAULT_ROUTE=$(ip route | egrep '^default ' | head -n1)
PUBLIC_INTERFACE=${DEFAULT_ROUTE##*dev }
PUBLIC_INTERFACE=${PUBLIC_INTERFACE/% */}
echo PUBLIC_INTERFACE="$PUBLIC_INTERFACE" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# IP address
DNS_RECORD=$(grep 'address=/host/' ../../host/etc/dnsmasq.d/eb_hosts | \
    head -n1)
IP=${DNS_RECORD##*/}
echo HOST="$IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# remote IP address
REMOTE_IP=$(ip addr show $PUBLIC_INTERFACE | ack "$PUBLIC_INTERFACE$" | \
            xargs | cut -d " " -f 2 | cut -d "/" -f1)
echo REMOTE_IP="$REMOTE_IP" >> \
    $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_NETWORK_INIT" = true ] && exit
cd $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER

echo
echo "------------------------- NETWORK --------------------------"

# -----------------------------------------------------------------------------
# BACKUP & STATUS
# -----------------------------------------------------------------------------
OLD_FILES="/root/eb_old_files/$DATE"
mkdir -p $OLD_FILES

# backup the files which will be changed
[ -f /etc/nftables.conf ] && cp /etc/nftables.conf $OLD_FILES/
[ -f /etc/network/interfaces ] && cp /etc/network/interfaces $OLD_FILES/
[ -f /etc/resolv.conf ] && cp /etc/resolv.conf $OLD_FILES/
[ -f /etc/dnsmasq.d/eb_hosts ] && \
    cp /etc/dnsmasq.d/eb_hosts $OLD_FILES/

# network status
echo "# ----- ip addr -----" >> $OLD_FILES/network.status
ip addr >> $OLD_FILES/network.status
echo >> $OLD_FILES/network.status
echo "# ----- ip route -----" >> $OLD_FILES/network.status
ip route >> $OLD_FILES/network.status

# nftables status
if [ "$(systemctl is-active nftables.service)" = "active" ]
then
	echo "# ----- nft list ruleset -----" >> $OLD_FILES/nftables.status
	nft list ruleset >> $OLD_FILES/nftables.status
fi

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# removed packages
apt-get -y remove iptables

# added packages
apt-get $APT_PROXY_OPTION -y install nftables

# -----------------------------------------------------------------------------
# NETWORK CONFIG
# -----------------------------------------------------------------------------
# changed/added system files
cp ../../host/etc/dnsmasq.d/eb_hosts /etc/dnsmasq.d/

# /etc/network/interfaces
[ -z "$(egrep '^source-directory\s*interfaces.d' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source-directory\s*/etc/network/interfaces.d' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*interfaces.d/\*' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*/etc/network/interfaces.d/\*' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*interfaces.d/eb_bridge' /etc/network/interfaces || true)" ] && \
[ -z "$(egrep '^source\s*/etc/network/interfaces.d/eb_bridge' /etc/network/interfaces || true)" ] && \
echo -e "\nsource /etc/network/interfaces.d/eb_bridge" >> /etc/network/interfaces

# IP forwarding
cp ../../host/etc/sysctl.d/eb_ip_forward.conf /etc/sysctl.d/
sysctl -p /etc/sysctl.d/eb_ip_forward.conf

# -----------------------------------------------------------------------------
# BRIDGE CONFIG
# -----------------------------------------------------------------------------
# private bridge interface for the containers
BR_EXISTS=$(brctl show | egrep "^$BRIDGE\s" || true)
[ -z "$BR_EXISTS" ] && brctl addbr $BRIDGE
ip link set $BRIDGE up
IP_EXISTS=$(ip a show dev $BRIDGE | egrep "inet $IP/24" || true)
[ -z "$IP_EXISTS" ] && ip addr add dev $BRIDGE $IP/24 brd 172.22.22.255

cp ../../host/etc/network/interfaces.d/eb_bridge /etc/network/interfaces.d/
sed -i "s/#BRIDGE#/${BRIDGE}/g" /etc/network/interfaces.d/eb_bridge
cp ../../host/etc/dnsmasq.d/eb_interface /etc/dnsmasq.d/
sed -i "s/#BRIDGE#/${BRIDGE}/g" /etc/dnsmasq.d/eb_interface

# -----------------------------------------------------------------------------
# NFTABLES
# -----------------------------------------------------------------------------
TABLE_EXISTS=$(nft list ruleset | grep "table inet eb-filter" || true)
[ -n "$TABLE_EXISTS" ] && nft delete table inet eb-filter

nft add table inet eb-filter
nft add chain inet eb-filter \
    input { type filter hook input priority 0 \; }
nft add chain inet eb-filter \
    forward { type filter hook forward priority 0 \; }
nft add chain inet eb-filter \
    output { type filter hook output priority 0 \; }
# drop packets coming from the public interface to the private network
nft add rule inet eb-filter output \
    iif $PUBLIC_INTERFACE ip daddr 172.22.22.0/24 drop

TABLE_EXISTS=$(nft list ruleset | grep "table ip eb-nat" || true)
[ -n "$TABLE_EXISTS" ] && nft delete table ip eb-nat

nft add table ip eb-nat
nft add chain ip eb-nat prerouting \
    { type nat hook prerouting priority 0 \; }
nft add chain ip eb-nat postrouting \
    { type nat hook postrouting priority 100 \; }
# masquerade packets coming from the private network
nft add rule ip eb-nat postrouting \
    ip saddr 172.22.22.0/24 masquerade

# dnat tcp maps
nft add map ip eb-nat tcp2ip \
    { type inet_service : ipv4_addr \; }
nft add map ip eb-nat tcp2port \
    { type inet_service : inet_service \; }
nft add rule ip eb-nat prerouting \
    iif $PUBLIC_INTERFACE dnat \
    tcp dport map @tcp2ip:tcp dport map @tcp2port

# dnat udp maps
nft add map ip eb-nat udp2ip \
    { type inet_service : ipv4_addr \; }
nft add map ip eb-nat udp2port \
    { type inet_service : inet_service \; }
nft add rule ip eb-nat prerouting \
    iif $PUBLIC_INTERFACE dnat \
    udp dport map @udp2ip:udp dport map @udp2port

# -----------------------------------------------------------------------------
# NETWORK RELATED SERVICES
# -----------------------------------------------------------------------------
# dnsmasq
systemctl stop dnsmasq.service
systemctl start dnsmasq.service

# nftables
systemctl enable nftables.service

# -----------------------------------------------------------------------------
# STATUS
# -----------------------------------------------------------------------------
ip addr
