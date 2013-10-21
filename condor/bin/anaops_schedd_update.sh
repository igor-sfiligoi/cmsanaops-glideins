#!/bin/bash

#
# Tool:
#  anaops_schedd_upgrade.sh
# 
# Arguments:
#  anaops_schedd_upgrade.sh -all|-config-only|-bin-only|-h
#
# Description:
#   This script upgrades a Condor schedd instance for
#     CMS AnaOps needs
#   It can be run on its own, as it will retrieve the latest copy
#     of the dependent files from CVS every time
#
# License:
#   MIT
#   Copyright (c) 2013 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

STARTDIR=$PWD

function usage {
  echo "Usage:" 1>&2
  echo " $0 -all|-config-only|-bin-only|-h" 1>&2
}

if [ $# -ne 1 ]; then
  usage
  echo "Wrong number of arguments" 1>&2
  exit 1
fi

case "$1" in
  "-all")
    update_confg=1
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

TMPDIR=`mktemp -d /root/anaops_si_XXXX`
if [ $? -ne 0 ]; then
  echo "mktemp failed" 1>&2
  exit 2
fi

cd $TMPDIR
if [ $? -ne 0 ]; then
  echo "Failed to use tmpdir: $TMPDIR" 1>&2
  exit 2
fi

CVSURL="http://cmscvs.cern.ch/cgi-bin/cmscvs.cgi/COMP/GLIDEINWMS/condor_config.tar.gz?view=tar"
wget -nv $CVSURL -O cvs.tgz
if [ $? -ne 0 ]; then
  echo "Failed to download the CVS tree: $CVSURL" 1>&2
  cd $STARTDIR
  rm -fr $TMPDIR
  exit 3
fi

tar -xzf cvs.tgz
if [ $? -ne 0 ]; then
  echo "Failed to untar the CVS tree" 1>&2
  cd $STARTDIR
  rm -fr $TMPDIR
  exit 3
fi

$PWD/condor_config/bin/anaops_schedd_update.donotrunbyhand.sh "$1"
rc=$?

cd $STARTDIR
rm -fr $TMPDIR
exit $rc
