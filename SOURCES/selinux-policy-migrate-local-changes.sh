#!/bin/bash
#===============================================================================
#
#          FILE: selinux-policy-migrate-local-changes.sh
# 
#         USAGE: ./selinux-policy-migrate-local-changes.sh <POLICYTYPE>
# 
#   DESCRIPTION: This script migrates local changes from pre-2.4 SELinux modules
#                store structure to the new structure
# 
#        AUTHOR: Petr Lautrbach <plautrba@redhat.com>
#===============================================================================

if [ ! -f /etc/selinux/config ]; then
    SELINUXTYPE=none
else
    source /etc/selinux/config
fi

REBUILD=0
MIGRATE_SELINUXTYPE=$1

for local in booleans.local file_contexts.local ports.local users_extra.local users.local; do
    if [ -e /etc/selinux/$MIGRATE_SELINUXTYPE/modules/active/$local ]; then
        REBUILD=1
        cp -v --preserve=mode,ownership,timestamps,links /etc/selinux/$MIGRATE_SELINUXTYPE/modules/active/$local /etc/selinux/$MIGRATE_SELINUXTYPE/active/$local
    fi
done
if [ -e /etc/selinux/$MIGRATE_SELINUXTYPE/modules/active/seusers ]; then
    REBUILD=1
    cp -v --preserve=mode,ownership,timestamps,links /etc/selinux/$MIGRATE_SELINUXTYPE/modules/active/seusers /etc/selinux/$MIGRATE_SELINUXTYPE/active/seusers.local
fi

INSTALL_MODULES=""
for i in `find /etc/selinux/$MIGRATE_SELINUXTYPE/modules/active/modules/ -name \*disabled 2> /dev/null`; do
    module=`basename $i | sed 's/\.pp\.disabled$//'`
    if [ $module == "pkcsslotd" ] || [ $module == "vbetool" ] || [ $module == "ctdbd" ] || [ $module == "docker" ] || [ $module == "gear" ]; then
        continue
    fi
    if [ -d /etc/selinux/$MIGRATE_SELINUXTYPE/active/modules/100/$module ]; then
        touch /etc/selinux/$MIGRATE_SELINUXTYPE/active/modules/disabled/$module
    fi
done
for i in `find /etc/selinux/$MIGRATE_SELINUXTYPE/modules/active/modules/ -name \*.pp 2> /dev/null`; do
    module=`basename $i | sed 's/\.pp$//'`
    if [ $module == "pkcsslotd" ] || [ $module == "vbetool" ] || [ $module == "ctdbd" ] || [ $module == "docker" ] || [ $module == "gear" ]; then
        continue
    fi
    if [ ! -d /etc/selinux/$MIGRATE_SELINUXTYPE/active/modules/100/$module ]; then
        INSTALL_MODULES="${INSTALL_MODULES} $i"
    fi
done
if [ -n "$INSTALL_MODULES" ]; then
    semodule -s $MIGRATE_SELINUXTYPE -n -X 400 -i $INSTALL_MODULES
    REBUILD=1
fi

cat > /etc/selinux/$MIGRATE_SELINUXTYPE/modules/active/README.migrated <<EOF
Your old modules store and local changes were migrated to the new structure in
in the following directory:

/etc/selinux/$MIGRATE_SELINUXTYPE/active

WARNING: Do not remove this file or remove /etc/selinux/$MIGRATE_SELINUXTYPE/modules
completely if you are confident that you don't need old files anymore.
EOF

if [ ${DONT_REBUILD:-0} = 0 -a $REBUILD = 1 ]; then
    semodule -B -n -s $MIGRATE_SELINUXTYPE
    if [ "$MIGRATE_SELINUXTYPE" = "$SELINUXTYPE" ] && selinuxenabled; then
        load_policy
        if [ -x /usr/sbin/semanage ]; then
            /usr/sbin/semanage export | /usr/sbin/semanage import
        fi
    fi
fi
