#!/bin/bash

#
# Tool:
#  install_condor.sh
# 
# Arguments:
#   install_condor.sh [-nolsb] <condor type> <target instdir> <condor dir> <gwms dir> <type> [<condor user> [<CMS dir>]]
#
# Description:
#   This script installs and configures a Condor instance for CMS use
#
# License:
#   MIT
#   Copyright (c) 2014 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

function usage {
  echo "Usage:" 1>&2
  echo " $0 [-nolsb] <condor type> <target instdir> <condor dir> <gwms dir> <type> [<condor user> [<CMS dir>]]" 1>&2
  echo  1>&2
}

myid=`id -un`

uselsb=1
if [ "$1" == "-nolsb" ]; then
  uselsb=0
  shift
else
  if [ "$myid" != "root" ]; then
    usage
    echo "You must be root to use the lsb setup" 1>&2
    exit 1
  fi
fi


if [ $# -lt 5 ]; then
  usage
  echo "Only $# argument(s) provided" 1>&2
  exit 1
fi

CTYPE=$1
INSTDIR=$2
CONDORDIR=$3
GWMS=$4
ITYPE=$5
if [ $# -ge 6 ]; then
   CONDORUSER=$6
else
   CONDORUSER=condor
fi

if [ "$myid" != "root" ]; then
  if [ "$CONDORUSER" != "$myid" ]; then
    usage
    echo "If not installing as root, must install as the condor user ($CONDORUSER!=$myid)" 1>&2
    exit 1
  fi
  OWNERSTR=""
else
  OWNERSTR="--owner=$CONDORUSER"
fi

if [ $# -ge 7 ]; then
   CMSDIR=$7
else
   CMSDIR=`dirname $0`/..
fi

if [[ "$CTYPE" != "schedd" && "$CTYPE" != "collector" ]]; then
  echo "Invalid condor type: $CTYPE" 1>&2
  echo "Only schedd and soon collector supported right now" 1>&2
  exit 1
fi

if [ -e "$INSTDIR/condor.sh" ]; then
  echo "Install dir seems to already contain a Condor instance: $INSTDIR" 1>&2
  echo "Use config_condor.sh to just update the config files" 1>&2
  echo "Aborting (clean it out, if you really want to re-install)" 1>&2
  exit 1
fi

if [ -e "$CONDORDIR/condor_install" ]; then
  true
else
  echo "Not a condor directory: $CONDORDIR"  1>&2
  echo "File not found: $CONDORDIR/condor_install" 1>&2
  exit 1
fi

$CONDORDIR/bin/condor_version
rc=$?

if [ $rc -ne 0 ]; then
  echo "Condor not usable, aborting" 1>&2
  exit 1
fi

if [ -e "$GWMS/install/templates/00_gwms_general.config" ]; then
  true
else
  echo "Not a glideinWMS directory: $GWMS"  1>&2
  echo "File not found: $GWMS/install/templates/00_gwms_general.config" 1>&2
  exit 1
fi

mflist="$CMSDIR/$ITYPE/cms_${CTYPE}_mapfiles.flist"
if [ -e "$mflist" ]; then
  true
else
  echo "Invalid instance type: $ITYPE"  1>&2
  echo "File not found: $mflist" 1>&2
  exit 1
fi

#
# Do some additional basic sanity checks
#
echo 'import M2Crypto' |python
rc=$?
if [ $rc -ne 0 ]; then
  echo "Missing needed python libraries, aborting" 1>&2
  exit 1
fi


STARTDIR=$PWD

#
# Install Condor
#
echo  "Installing condor"
echo

if [[ "$CTYPE" == "schedd" ]]; then
  cd $CONDORDIR && \
  ./condor_install --prefix=$INSTDIR --local-dir=$INSTDIR/condor_local $OWNERSTR \
  --type=submit  --central-manager=fake
  rc=$?
else
  cd $CONDORDIR && \
  ./condor_install --prefix=$INSTDIR --local-dir=$INSTDIR/condor_local $OWNERSTR \
  --type=manager
  rc=$?
fi

if [ $rc -ne 0 ]; then
  echo "Condor installation failed" 1>&2
  echo "You may need to wipe $INSTDIR" 1>&2
  exit 1
fi
 
cd $STARTDIR

echo "Creating basic config dirs and files"
echo

# Condor is configured to use the config dir, but does not create it
cdir=$INSTDIR/condor_local/config
mkdir $cdir

# We will need a dir for the mapfile
mkdir $INSTDIR/certs

if [ "$uselsb" -eq 1 ]; then
  echo "Putting Condor in LSB locations"
  echo

  # Put everything in the standard places
  # Use the script in this repository
  cd $CMSDIR/bin
  ./glidecondor_linkLSB $INSTDIR
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "Failed to create LSB links" 1>&2
    echo "You may need to wipe $INSTDIR" 1>&2
    exit 1
  fi

  cd $STARTDIR
  source /etc/profile.d/condor.sh
else
  if [ "$myid" != "root" ]; then
      nlsbcfg=13_cms_userspace.config
  else
      nlsbcfg=09_gwms_local_nolsb.config
  fi

  echo "Patching configs to allow for non-LSB setup"
  echo
  cp $CMSDIR/generic/$nlsbcfg $cdir/
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "Failed to copy $CMSDIR/generic/$nlsbcfg into $cdir" 1>&2
    echo "You may need to wipe $INSTDIR" 1>&2
    exit 1
  fi

  source $INSTDIR/condor.sh
fi

echo "Doing detailed condor config"
echo

$CMSDIR/bin/config_condor.sh "$CTYPE" "$GWMS" "$ITYPE" "$CMSDIR"
rc=$?
if [ $rc -ne 0 ]; then
  echo "Failed to configure condor" 1>&2
  echo "You may need to wipe $INSTDIR" 1>&2
  echo "    as well as clean the system locations" 1>&2 
  exit 1
fi

echo "Condor installed and configured"
if [[ "$CTYPE" == "schedd" ]]; then
  echo "Make sure you have authorized this schedd in your Collector"
  echo "and added it to the list of schedds in the Frontend"
fi

echo

if [ "$uselsb" -ne 1 ]; then
    echo "Note: Condor not in the path"
    echo "      You may need to source $INSTDIR/condor.sh"
else
    echo "Condor will be in the path next time you log back in"
    echo "You can control the daemons with"
    echo "  /etc/init.d/condor start|stop"
fi

