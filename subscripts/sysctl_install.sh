#!/bin/bash

##########################################################################################
## DEPRECATED: This script is now replaced by network_security.sh
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="sysctl_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Migration Notice
##########################################################################################

show_warn "NOTICE: This script has been replaced by network_security.sh"
show_warn "The new script provides comprehensive network security configuration"
show_warn "including sysctl hardening, DNS security, and network interface protection."
show_warn ""
show_warn "This script will continue to work for compatibility but is deprecated."
show_warn "Please use the new security-focused script structure."

##########################################################################################
## Compatibility execution - just run basic sysctl if really needed
##########################################################################################

##########################################################################################
## Copy sysctl config
##########################################################################################

if [ -a $CONF_ORG ]; then
    cp -p $CONF_ORG $CONF_BACK && show_yellow "Sysctl file $CONF_ORG backed up to $CONF_BACK."
    cp $CONF_GIT $CONF_ORG && show_yellow "Default sysctl configuration deployed."
else
    cp $CONF_GIT $CONF_ORG && show_yellow "Default sysctl configuration deployed."
fi

##########################################################################################
## Restart sysctl
##########################################################################################

sysctl -p >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Sysctl restart failed. Please check logfile and fix error manually.")
show_yellow "Sysctl restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Please check $CONF_ORG manually for swap settings."
