#!/bin/bash

#
# Tool:
#  anaops_schedd_install.donotrunbyhand.sh
# 
# Arguments:
#   anaops_schedd_install.donotrunbyhand.sh <site>|-auto|-h
#
# Description:
#   This script installs and configures a Condor schedd instance for
#     CMS AnaOps needs
#   It is not meant to be run directly, but should be invoked by
#     anaps_schedd_install.sh 
#   instead
#
# Assumption:
#   The directory we are starting in is clean and can be used as tmp space
#
# License:
#   MIT
#   Copyright (c) 2013 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

function fail {
  echo "WARINING: Did not complete intallation" 1>&2
  exit $1
}

function usage {
  echo "Usage (but do not run by hand):" 1>&2
  echo " $0 <site>|-auto|-h" 1>&2
}

if [ $# -ne 1 ]; then
  usage
  echo "Wrong number of arguments" 1>&2
  fail 1
fi

if [ "$1" == "-h" ]; then
  usage
  exit 0
fi

site=$1

if [ "`id -un`" != "root" ]; then
  echo "You must be root to run this command" 1>&2
  echo "Aborting" 1>&2
  fail 2
fi


if [ "$site" == "-auto" ]; then
  dnssite=`dnsdomainname`
  case "$dnssite" in 
    "t2.ucsd.edu")
       site="UCSD"
       ;;
    "unl.edu")
       site="UNL"
       ;;
    "cern.ch")
       site="CERN"
       ;;
    *)
       echo "This domain is unknown, autodetection failed: $dnssite" 1>&2
       exit 2
       ;;
  esac
fi

CMSBIN=`dirname $0`

source $CMSBIN/../anaops_ucsd/anaops_consts.source

if [[ "$GWMSTAR" == "" || "$TARURL" == ""  || "$CONDORTAR" == "" ]]; then
  echo "Failed sourcing $CMSBIN/../anaops_ucsd/anaops_consts.source" 1>&2
  echo "Some of the expected variables are not defined" 1>&2
  fail 2
fi
 
case "$site" in
  UCSD)
    ANATYPE=anaops_ucsd
    CONDORUSER=condor
    INSTDIR=/opt/glidecondor
    ;;
  UNL)
    ANATYPE=anaops_ucsd
    CONDORUSER=condor
    INSTDIR=/opt/glidecondor
    ;;
  CERN)
    ANATYPE=anaops_cern
    CONDORUSER=_condor
    INSTDIR=/data/srv/glidecondor
    ;;
  CERNGlobal)
    ANATYPE=global_cern
    CONDORUSER=_condor
    INSTDIR=/data/srv/glidecondor
    ;;
  *)
     echo "Site not supported: $site" 1>&2
     fail 2
     ;;
esac

rm -f $GWMSTAR $CONDORTAR
wget -nv $TARURL/$GWMSTAR && wget -nv $TARURL/$CONDORTAR
if [ $? -ne 0 ]; then
  echo "Failed to download tarballs from $TARURL" 1>&2
  fail 2
fi


tar -xzf $GWMSTAR && tar -xzf $CONDORTAR
if [ $? -ne 0 ]; then
  echo "Failed to extract tarballs" 1>&2
  fail 2
fi

GWMSDIR=$PWD/glideinwms
CONDORDIR=$PWD/`echo $CONDORTAR |awk '{split($0,a,"\\\\.t"); print a[1]}'`

if [ "$PCONDORTAR" != "fake" ]; then 
    rm -f $PCONDORTAR
    wget -nv $TARURL/$PCONDORTAR
    if [ $? -ne 0 ]; then
	echo "Failed to download patch tarbals from $TARURL" 1>&2
	fail 2
    fi


    tar -xzf $PCONDORTAR
    if [ $? -ne 0 ]; then
	echo "Failed to extract patch tarball" 1>&2
	fail 2
    fi
    PCONDORDIR=$PWD/`echo $PCONDORTAR |awk '{split($0,a,"\\\\.t"); print a[1]}'`
fi


$CMSBIN/install_condor.sh schedd $INSTDIR $CONDORDIR $GWMSDIR $ANATYPE $CONDORUSER
if [ $? -ne 0 ]; then
  # the command errors should be self reporting
  fail 3
fi

echo -e "cmstype = $ANATYPE\ncondortype = schedd" >  $INSTDIR/condor_local/cms_install.conf

if [ "$PCONDORTAR" != "fake" ]; then 
    $CMSBIN/../crab2_rcondor/cms_schedd_patch.sh $PCONDORDIR
    if [ $? -ne 0 ]; then
  # the command errors should be self reporting
	fail 3
    fi
fi

echo "Condor installation and configuration successfully completed"

exit 0
