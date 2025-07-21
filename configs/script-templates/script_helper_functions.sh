#!/bin/bash

# Helper functions for script template management
# Ubuntu 24.04 Server Automation

##########################################################################################
## Helper function for copying and configuring script templates
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

# Function to replace placeholder variables in a script
replace_script_variables() {
    local script_path="$1"
    
    if [ ! -f "$script_path" ]; then
        echo "Error: Script file $script_path not found"
        return 1
    fi
    
    # Replace Slack webhook URL
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        sed -i 's|{{SLACK_WEBHOOK_URL}}|'${SLACK_WEBHOOK_URL}'|g' "$script_path"
    else
        # Leave placeholder unchanged so scripts will skip Slack notifications
        # This maintains backward compatibility
        echo "Slack monitoring disabled - notifications will be skipped"
    fi
    
    # Replace email configuration
    if [ -n "$INFO_EMAIL" ]; then
        sed -i 's|{{INFO_EMAIL}}|'${INFO_EMAIL}'|g' "$script_path"
    fi
    
    if [ -n "$EMAIL_DOMAIN" ]; then
        sed -i 's|{{EMAIL_DOMAIN}}|'${EMAIL_DOMAIN}'|g' "$script_path"
    fi
    
    echo "Variables replaced in $script_path"
}

# Function to verify script template variables
verify_script_template() {
    local script_path="$1"
    local template_name="$2"
    
    if [ ! -f "$script_path" ]; then
        echo "Error: Cannot verify script $script_path - file not found"
        return 1
    fi
    
    # Check for unreplaced placeholders
    local unreplaced=$(grep -o '{{[^}]*}}' "$script_path" 2>/dev/null || true)
    
    if [ -n "$unreplaced" ]; then
        echo "Warning: Unreplaced placeholders found in $template_name:"
        echo "$unreplaced"
    else
        echo "✓ All placeholders replaced in $template_name"
    fi
}

##########################################################################################
## Export functions for use in other scripts
##########################################################################################

# Make functions available to sourcing scripts
export -f copy_and_configure_script
export -f replace_script_variables
export -f verify_script_template 