#!/bin/bash

#
# Tool:
#  config_schedd.sh
# 
# Arguments:
#   config_schedd_.sh <condor type> <gwms dir> <type> [<CVS dir>]
#
# Description:
#   This script (re-)creates the config files for a CMS Schedd installation
#
# License:
#   MIT
#   Copyright (c) 2013 Igor Sfiligoi <isfiligoi@ucsd.edu>
#

if [ $# -lt 3 ]; then
  echo "Usage:" 1>&2
  echo " $0 <condor type> <gwms dir> <type> [<CVS dir>]" 1>&2
  echo  1>&2
  echo "Only $# argument(s) provided" 1>&2
  exit 1
fi

CTYPE=$1
GWMS=$2
ITYPE=$3
if [ $# -ge 4 ]; then
   CMSDIR=$4
else
   CMSDIR=`dirname $0`/..
fi

if [[ "$CTYPE" != "schedd" && "$CTYPE" != "collector" ]]; then
  echo "Invalid condor type: $CTYPE" 1>&2
  echo "Only schedd (and soon collector) supported right now" 1>&2
  exit 1
fi

if [ -e "$GWMS/install/templates/00_gwms_general.config" ]; then
  true
else
  echo "Not a glideinWMS directory: $GWMS"  1>&2
  echo "File not found: $GWMS/install/templates/00_gwms_general.config" 1>&2
  exit 1
fi

cflist="$CMSDIR/$ITYPE/cms_${CTYPE}_configs.flist"
if [ -e "$cflist" ]; then
  true
else
  echo "Invalid instance type: $ITYPE"  1>&2
  echo "File not found: $cflist" 1>&2
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

cfiles=`$CMSDIR/bin/get_file_list.py $cflist`
if [ $? -ne 0 ]; then
  echo "Failed to read config file list" 1>&2
  exit 1
fi

mfiles=`$CMSDIR/bin/get_file_list.py $mflist`
if [ $? -ne 0 ]; then
  echo "Failed to read mapfile list" 1>&2
  exit 1
fi

STARTDIR=$PWD

################################################
cdir=`condor_config_val LOCAL_CONFIG_DIR`
if [ $? -ne 0 ]; then
  echo "Could not find config dir" 1>&2
  exit 1
fi

# gwms templates will undefine a few attributes too many
# put local config after them
lclink="$cdir/09_condor_local.config"
lcfile=`condor_config_val LOCAL_CONFIG_FILE`
if [ $? -ne 0 ]; then
  if [ -e "$lclink" ]; then 
   rm -f "$lclink"
  fi
else
  if  [ -e "$lclink" ]; then 
   true
  else
   ln -s "$lcfile" "$lclink"
  fi
fi

twfile="$cdir/99_local_tweaks.config"
if [ -e "$twfile" ]; then
  true
else
  # Create an empty "tweak file", if there is none yet
  touch $cdir/99_local_tweaks.config
fi


echo "Copying the glideinWMS template config files"
echo

# now copy the base gwms templates in the config file
if [[ "$CTYPE" == "schedd" ]]; then
  gtfiles="00_gwms_general.config 02_gwms_schedds.config 03_gwms_local.config"
else
  echo "this condor type is not yet supported: $CTYPE" 1>&2
  exit 1
fi
for f in $gtfiles; do
  cp $GWMS/install/templates/$f $cdir/ 
  if [ $? -ne 0 ]; then
    echo "Failed to copy $GWMS/install/templates/$f into $cdir" 1>&2
    exit 1
  fi
done

echo "Copying instance type specfic config files"
echo

# followed by the instance specific files
for f in $cfiles; do
  cp $f $cdir/ 
  if [ $? -ne 0 ]; then
    echo "Failed to copy $f into $cdir" 1>&2
    exit 1
  fi
done

echo "Creating mapfile"

# create the mapfile
# by concatenating the instance mpfs and the template
mpf=`condor_config_val CERTIFICATE_MAPFILE`
if [ $? -ne 0 ]; then
  echo "Could not find config dir" 1>&2
  exit 1
fi

if [ -f "$mpf" ]; then
    mv "$mpf" "$mpf.old.`date +%s`~"
fi
if [ -f "$mpf" ]; then
  echo "Old mapfile exists, and could not be removed: $mpf" 1>&2
  exit 1
fi

echo "...startic part"

touch $mpf
for f in $mfiles $GWMS/install/templates/condor_mapfile ; do
  cat $f >> $mpf 
  if [ $? -ne 0 ]; then
    echo "Failed to append $f to $mpf" 1>&2
    echo "Condor is likely misconfigured now" 1>&2
    exit 1
  fi
done

echo "...dynamic part"

# Use the glideinMS helper script to put our own DN into the mapfile
mpf=$cdir/90_gwms_dns.config
if [ -f "$mpf" ]; then
    mv "$mpf" "$mpf.old.`date +%s`~"
fi
if [ -f "$mpf" ]; then
  echo "Old config exists, and could not be removed: $mpf" 1>&2
  exit 1
fi

hostcert=`condor_config_val GSI_DAEMON_CERT`
if [ $? -ne 0 ]; then
  echo "Could not find host cert" 1>&2
  echo "Condor is likely misconfigured now" 1>&2
  exit 1
fi

touch $cdir/90_gwms_dns.config
cd $GWMS/install; \
 ./glidecondor_addDN \
    -daemon My_hostcert_distinguished_name \
    "$hostcert" condor
if [ $? -ne 0 ]; then
  echo "Failed to add my own DN" 1>&2
  echo "Condor is likely misconfigured now" 1>&2
  exit 1
fi

echo

cd $STARTDIR

echo
echo "Condor (re-)configured"
echo
echo "Reminder:"
echo " Never ever modify any of the files created by this script"
echo " with the only exception being 99_local_tweaks.config."
echo " Put all of your changes in that file, or create your own, new file(s)"
echo
