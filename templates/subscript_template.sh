#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="subscript_template.sh"
LOGFILE=$SUBSCRIPT-$DATE.log

CONF_ORG=<path-to-original-config-file>
CONF_BACK=${CONF_ORG}_$DATE
CONF_GIT=$BASEDIR/configs/<service>/<config-file-name>

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Run routine
##########################################################################################

COMMAND_TO_BE_RUN > $LOGDIR/$LOGFILE 2>&1 || ( show_error "Installation of <something> failed. Please check logfile and fix error manually.")
show_yellow "Installation of <something> done."

OTHER_COMMAND_TO_BE_RUN >> $LOGDIR/$LOGFILE 2>&1 || ( show_error "Installation of <something-else> failed. Please check logfile and fix error manually."; exit 1 )
show_yellow "Installation of <something-else> done."

##########################################################################################
## Backup and deploy default config
##########################################################################################

cp -p $CONF_ORG $CONF_BACK && show_yellow "Config file $CONF_ORG backed up to $CONF_BACK."
cp $CONF_GIT $CONF_ORG && show_yellow "Default <some-service> config file deployed."

##########################################################################################
## DONE
##########################################################################################

show_info "$SUBSCRIPT done."
