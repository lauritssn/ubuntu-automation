#!/bin/bash

##########################################################################################
## DEPRECATED - Legacy Compatibility Layer
## This file now sources the new shared_functions.sh for backward compatibility
##########################################################################################

# Try to find and source the new shared functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
elif [ -f "$(dirname "$0")/../../utils/shared_functions.sh" ]; then
    source "$(dirname "$0")/../../utils/shared_functions.sh"
elif [ -f "/srv/apps/scripts/shared_functions.sh" ]; then
    source "/srv/apps/scripts/shared_functions.sh"
else
    echo "Warning: Could not find shared_functions.sh - using legacy functions"
    
    ##########################################################################################
    ## Legacy helper functions (deprecated - use shared_functions.sh instead)
    ##########################################################################################
    
    # Function to copy script template and replace variables
    copy_and_configure_script() {
        local template_name="$1"
        local destination_path="$2"
        local script_name="$3"

        # Validate parameters
        if [ -z "$template_name" ] || [ -z "$destination_path" ]; then
            echo "Error: copy_and_configure_script requires template_name and destination_path"
            return 1
        fi

        local template_path="$BASEDIR/configs/script-templates/$template_name"

        # Check if template exists
        if [ ! -f "$template_path" ]; then
            echo "Error: Template $template_path not found"
            return 1
        fi

        echo "Creating $script_name from template $template_name"

        # Copy template to destination
        cp "$template_path" "$destination_path"

        # Replace placeholder variables
        replace_script_variables "$destination_path"

        # Make script executable
        chmod +x "$destination_path"

        echo "Script created and configured: $destination_path"
        return 0
    }

    # Legacy function to replace placeholder variables in a script
    replace_script_variables() {
        local script_path="$1"

        if [ ! -f "$script_path" ]; then
            echo "Error: Script file $script_path not found"
            return 1
        fi

        # Replace common placeholder variables with fallback values
        sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$script_path"
        sed -i "s|{{EMAIL_DOMAIN}}|${EMAIL_DOMAIN:-example.com}|g" "$script_path"
        sed -i "s|{{INFO_EMAIL}}|${INFO_EMAIL:-admin@example.com}|g" "$script_path"
        sed -i "s|{{TIMEZONE}}|${TIMEZONE:-UTC}|g" "$script_path"
        sed -i "s|{{SECURE_SUBNET}}|${SECURE_SUBNET:-}|g" "$script_path"
        sed -i "s|{{SECURE_SUBNET_DESC}}|${SECURE_SUBNET_DESC:-}|g" "$script_path"
        sed -i "s|{{LOGDIR}}|${LOGDIR:-/srv/apps/logs}|g" "$script_path"
        sed -i "s|{{SCRIPTSDIR}}|${SCRIPTSDIR:-/srv/apps/scripts}|g" "$script_path"
        sed -i "s|{{BACKUPDIR}}|${BACKUPDIR:-/srv/apps/backups}|g" "$script_path"

        return 0
    }
fi
