#!/bin/bash

# -----------------------------------------------------------------------------
# POST_INSTALL_NFTABLES.SH
# -----------------------------------------------------------------------------
set -e
source $BASEDIR/$GIT_LOCAL_DIR/installer_sub_scripts/$INSTALLER/000_source

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_POST_INSTALL" = true ] && exit

# -----------------------------------------------------------------------------
# NFTABLES
# -----------------------------------------------------------------------------
# recreate nftables.conf
cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

EOF

# save ruleset
# 
nft list ruleset -nn >> /etc/nftables.conf
