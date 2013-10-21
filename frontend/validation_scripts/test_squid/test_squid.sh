#!/bin/bash

# set return code behaviour for squid/frontier test:
export SAME_OK=0
export SAME_WARNING=0
export SAME_ERROR=1

# set up interface to condor:
glidein_config="$1"
condor_vars_file=`awk '/^CONDOR_VARS_FILE /{print $2}' $glidein_config`
add_config_line_source=`awk '/^ADD_CONFIG_LINE_SOURCE /{print $2}' $glidein_config`
source $add_config_line_source

# big fix for glideinWMS:
function warn {
  echo `date` $@ 1>&2
}

# set up CMSSW environment; CMS_PATH needed for squid/frontier test:
if [ -f "$VO_CMS_SW_DIR/cmsset_default.sh" ]; then
  echo "Found CMS SW in $VO_CMS_SW_DIR" 1>&2
  source "$VO_CMS_SW_DIR/cmsset_default.sh"
elif [ -f "$OSG_APP/cmssoft/cms/cmsset_default.sh" ]; then
  echo "Found CMS SW in $OSG_APP/cmssoft/cms" 1>&2
  source "$OSG_APP/cmssoft/cms/cmsset_default.sh"
else
  echo "cmsset_default.sh not found!\n" 1>&2
  echo "Looked in $VO_CMS_SW_DIR/cmsset_default.sh" 1>&2
  echo "and $OSG_APP/cmssoft/cms/cmsset_default.sh" 1>&2
  exit 1
fi

# Find and execute the squid/frontier test for CMS
my_tar_dir=`grep -i '^GLIDECLIENT_CMS_TEST_SQUID ' $glidein_config | awk '{print $2}'`
${my_tar_dir}/test_squid.py 
RC=$?

add_config_line "CMS_VALIDATION_FRONTIER" $RC
add_condor_vars_line "CMS_VALIDATION_FRONTIER" "S" "-" "+" "N" "Y" "+"
exit $RC
