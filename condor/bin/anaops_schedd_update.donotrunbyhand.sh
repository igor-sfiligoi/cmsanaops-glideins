#!/bin/bash

#
# Tool:
#  anaops_schedd_update.donotrunbyhand.sh
# 
# Arguments:
#  anaops_schedd_upgrade.donotrunbyhand.sh -all|-config-only|-bin-only|-h
#
# Description:
#   This script upgrades a Condor schedd instance for
#     CMS AnaOps needs
#   It is not meant to be run directly, but should be invoked by
#     anaps_schedd_update.sh 
#   instead
#
# Assumption:
#   The directory we are starting in is clean and can be used as tmp space
#
# License:
#   MIT
#   Copyright (c) 2013 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

function usage {
  echo "Usage (but do not run by hand):" 1>&2
  echo " $0 -all|-config-only|-bin-only|-h" 1>&2
}

if [ $# -ne 1 ]; then
  usage
  echo "Wrong number of arguments" 1>&2
  exit 1
fi

case "$1" in
  "-all")
    update_config=1
    update_bin=1
    ;;
  "-config-only")
    update_config=1
    update_bin=0
    ;;
  "-bin-only")
    update_config=0
    update_bin=1
    ;;
  "-h")
    usage
    exit 0
    ;;
  *)
    usage
    echo "Unsupported option $1" 1>&2
    exit 1
esac

if [ "`id -un`" != "root" ]; then
  echo "You must be root to run this command" 1>&2
  echo "Aborting" 1>&2
  exit 2
fi

if [ $update_bin -eq 1 ]; then
    cmaster=`ps -ef |grep condor_master |wc -l`
    if [ "$cmaster" == "1" ]; then
        # just my grep command
	true
    else
	echo "Condor must be stopped before upgrading the binaries" 1>&2
	exit 1
    fi
fi

cdir=`condor_config_val LOCAL_DIR`
if [ $? -ne 0 ]; then
  echo "Could not find condor local dir" 1>&2
  exit 2
fi

# check that this is actually a compatible install
ctype=`grep '^condortype = schedd$' $cdir/cms_install.conf`
if [ "$ctype" == "condortype = schedd" ]; then
  true
else
  echo "Not a compatible installation, expected condortype = schedd"1>&2
  cat  $cdir/cms_install.conf 1>&2
  exit 2
fi

anatype=`grep '^cmstype = ' $cdir/cms_install.conf | awk '{print $3}'`
if [ "${anatype:0:7}" == "anaops_" ]; then
  true
else
  echo "Not an anaops installation: $anatype" 1>&2
  exit 2
fi

CMSBIN=`dirname $0`

source $CMSBIN/../anaops_ucsd/anaops_consts.source

if [[ "$GWMSTAR" == "" || "$TARURL" == ""  || "$CONDORTAR" == "" ]]; then
  echo "Failed sourcing $CMSBIN/../anaops_ucsd/anaops_consts.source" 1>&2
  echo "Some of the expected variables are not defined" 1>&2
  exit 2
fi

rm -f $GWMSTAR
wget -nv $TARURL/$GWMSTAR
if [ $? -ne 0 ]; then
    echo "Failed to download gwms tarball from $TARURL" 1>&2
    exit 2
fi

tar -xzf $GWMSTAR
if [ $? -ne 0 ]; then
    echo "Failed to extract gwms tarball" 1>&2
    exit 2
fi

GWMSDIR=$PWD/glideinwms

if [ $update_bin -eq 1 ]; then
    rm -f $CONDORTAR
    wget -nv $TARURL/$CONDORTAR
    if [ $? -ne 0 ]; then
	echo "Failed to download condor tarball from $TARURL" 1>&2
	exit 2
    fi
    CONDORDIR=$PWD/`echo $CONDORTAR |awk '{split($0,a,"\\\\.t"); print a[1]}'`

    if [ "$PCONDORTAR" != "fake" ]; then
	rm -f $PCONDORTAR
	wget -nv $TARURL/$PCONDORTAR
	if [ $? -ne 0 ]; then
	    echo "Failed to download condor patch tarball from $TARURL" 1>&2
	    exit 2
	fi

	tar -xzf $PCONDORTAR
	if [ $? -ne 0 ]; then
	    echo "Failed to extract condor patch tarball" 1>&2
	    exit 2
	fi

	PCONDORDIR=$PWD/`echo $PCONDORTAR |awk '{split($0,a,"\\\\.t"); print a[1]}'`
    fi

    # This will upgrade the binaries
    $GWMSDIR/install/glidecondor_upgrade $CONDORTAR
    if [ $? -ne 0 ]; then
	echo "Failed to upgrade Condor binaries" 1>&2
	exit 2
    fi
    
    if [ "$PCONDORTAR" != "fake" ]; then 
        # but now we have to re-patch, too
	$CMSBIN/../crab2_rcondor/cms_schedd_patch.sh $PCONDORDIR
	if [ $? -ne 0 ]; then
            # the command errors should be self reporting
	    exit 3
	fi
    fi
fi
 
if [ $update_config -eq 1 ]; then
    $CMSBIN/config_condor.sh schedd $GWMSDIR $anatype
    if [ $? -ne 0 ]; then
        # the command errors should be self reporting
	exit 3
    fi
fi

echo "Upgrade successfuly completed"
if [ $update_bin -eq 1 ]; then
    echo "Remember to start the Condor daemons"
else
    echo "Remember to reconfg or restart the Condor daemons"
fi

exit 0
