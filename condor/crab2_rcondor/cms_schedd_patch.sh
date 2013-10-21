#!/bin/bash

#
# Tool:
#  cms_schedd_patch.sh
# 
# Arguments:
#  cms_schedd_patch.sh <condor dir>
#
# Description:
#   This script patches the schedd for CRAB2 RCondor setups
#
# License:
#   MIT
#   Copyright (c) 2013 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

function usage {
  echo "Usage:" 1>&2
  echo " $0 <condor dir>" 1>&2
  echo  1>&2
}

if [ $# -lt 1 ]; then
  usage
  echo "No arguments provided" 1>&2
  exit 1
fi

if [ $# -gt 1 ]; then
  usage
  echo "Too many arguments provided" 1>&2
  exit 1
fi

if [ "$1" == "-h" ]; then
  usage
  exit 0
fi

CONDORDIR=$1
if [ -f "$CONDORDIR/bin/condor_history" ]; then
  true
else
  usage
  echo "No a Condor directory: $CONDORDIR" 1>&2
  echo "File does not exist: $CONDORDIR/bin/condor_history" 1>&2
  exit 1
fi

clib=`condor_config_val LIB`
if [ $? -ne 0 ]; then
  echo "Could not find the existing LIB dir" 1>&2
  exit 2
fi

cbin=`condor_config_val BIN`
if [ $? -ne 0 ]; then
  echo "Could not find the existing BIN dir" 1>&2
  exit 2
fi


echo "Copying over the needed library files"
echo "If prompted to overwrite any library, answer N"
(yes n | cp -i $CONDORDIR/lib/*.so* $clib/ 2>/dev/null) && \
(yes n | cp -i $CONDORDIR/lib/condor/* $clib/condor/ 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Failed to copy over the library files" 1>&2
  exit 2
fi

# now replace the condor_history file
mv $cbin/condor_history $cbin/condor_history.old.`date +%s` &&\
cp $CONDORDIR/bin/condor_history $cbin/
if [ $? -ne 0 ]; then
  echo "Failed to put in place the new history file" 1>&2
  exit 2
fi
