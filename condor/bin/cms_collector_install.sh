#!/bin/bash

#
# Tool:
#  cms_collector_install.sh
# 
# Arguments:
#  cms_collector_install.sh <site>|-auto|-h
#
# Description:
#   This script installs and configures a Condor collector instance for
#     CMS needs
#   It can be run on its own, as it will retrieve the latest copy
#     of the dependent files from git every time
#
# License:
#   MIT
#   Copyright (c) 2013 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

STARTDIR=$PWD

function usage {
  echo "Usage:" 1>&2
  echo " $0 <site>|-auto|-h" 1>&2
}

if [ $# -ne 1 ]; then
  usage
  echo "Wrong number of arguments" 1>&2
  exit 1
fi

if [ "$1" == "-h" ]; then
  usage
  exit 0
fi

site=$1

if [ "`id -un`" != "root" ]; then
  echo "You must be root to run this command" 1>&2
  echo "Aborting" 1>&2
  exit 2
fi


TMPDIR=`mktemp -d /home/condor/cms_si_XXXX`
if [ $? -ne 0 ]; then
  echo "mktemp failed" 1>&2
  exit 2
fi

cd $TMPDIR
if [ $? -ne 0 ]; then
  echo "Failed to use tmpdir: $TMPDIR" 1>&2
  exit 2
fi

GITURL="https://github.com/igor-sfiligoi/cmsanaops-glideins/archive/master.zip"
wget -nv $GITURL -O cms_git.zip
if [ $? -ne 0 ]; then
  echo "Failed to download the GIT tree: $GITURL" 1>&2
  cd $STARTDIR
  rm -fr $TMPDIR
  exit 3
fi

unzip -q cms_git.zip
if [ $? -ne 0 ]; then
  echo "Failed to unzip the GIT tree" 1>&2
  cd $STARTDIR
  rm -fr $TMPDIR
  exit 3
fi

$PWD/cmsanaops-glideins-master/condor/bin/cms_collector_install.donotrunbyhand.sh "$site"
rc=$?

cd $STARTDIR
rm -fr $TMPDIR
exit $rc
