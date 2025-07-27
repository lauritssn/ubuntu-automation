#!/bin/bash

##########################################################################################
## Safe sed operations with proper escaping for Ubuntu automation scripts
##########################################################################################

# Function to safely escape special characters for sed
escape_for_sed() {
    local input="$1"
    # Escape special characters that have meaning in sed
    printf '%s\n' "$input" | sed 's/[\/\&]/\\&/g; s/\*/\\*/g; s/\^/\\^/g; s/\$/\\$/g; s/\[/\\[/g; s/\]/\\]/g'
}

# Function to safely replace email placeholders (supports both old and new template formats)
replace_email_placeholder() {
    local file="$1"
    local placeholder="$2"
    local email="$3"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    if [ -z "$email" ]; then
        echo "Error: Email address is empty" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Escape email for sed
    local escaped_email
    escaped_email=$(escape_for_sed "$email")
    
    # Handle both template formats: {{PLACEHOLDER}} and PLACEHOLDER
    # First try new template format with double braces
    if grep -q "{{$placeholder}}" "$file"; then
        sed -i "s/{{$placeholder}}/$escaped_email/g" "$file"
    else
        # Fallback to old format for backward compatibility
        sed -i "s/$placeholder/$escaped_email/g" "$file"
    fi
}

# Function to safely set configuration values with tabs
set_config_with_tabs() {
    local file="$1"
    local key="$2"
    local value="$3"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Use printf to ensure proper tab handling
    sed -i "s/^${key}.*/$(printf "${key}\t${value}")/" "$file"
}

# Function to safely add configuration line if it doesn't exist
add_config_if_missing() {
    local file="$1"
    local config_line="$2"
    local search_pattern="$3"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    if ! grep -q "$search_pattern" "$file"; then
        echo "$config_line" >> "$file"
        return 0
    else
        echo "Configuration already exists in $file"
        return 1
    fi
}

# Function to safely comment out lines
comment_out_lines() {
    local file="$1"
    local pattern="$2"
    local comment_char="${3:-#}"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Comment out matching lines
    sed -i "s/^$pattern/$comment_char&/" "$file"
}

# Function to safely replace key=value configuration with email
safe_config_replace_email() {
    local file="$1"
    local key="$2"
    local email="$3"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    if [ -z "$email" ]; then
        echo "Error: Email address is empty" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Escape the email for sed (handle special characters)
    local escaped_email
    escaped_email=$(escape_for_sed "$email")
    
    # Replace the configuration line
    sed -i "s/^${key}=.*/${key}=\"${escaped_email}\"/" "$file"
}

# Function to safely replace key=value configuration with simple value
safe_config_replace() {
    local file="$1"
    local key="$2"
    local value="$3"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Escape the value for sed
    local escaped_value
    escaped_value=$(escape_for_sed "$value")
    
    # Replace the configuration line
    sed -i "s/^${key}=.*/${key}=${escaped_value}/" "$file"
}

# Function to safely replace configuration with paths (handles forward slashes)
safe_config_replace_path() {
    local file="$1"
    local key="$2"
    local path_value="$3"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Use alternate separator for sed to avoid issues with forward slashes
    sed -i "s|^${key}=.*|${key}=\"${path_value}\"|" "$file"
}

# Function to safely replace patterns in aliases file
safe_alias_replace() {
    local file="$1"
    local alias_name="$2"
    local email="$3"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    if [ -z "$email" ]; then
        echo "Error: Email address is empty" >&2
        return 1
    fi
    
    # Use alternate separator and escape email properly
    local escaped_email
    escaped_email=$(escape_for_sed "$email")
    
    # Replace alias line
    sed -i "s|^${alias_name}:.*|${alias_name}: ${escaped_email}|" "$file"
}

# Function to safely insert JSON configuration
safe_json_insert() {
    local file="$1"
    local json_key="$2"
    local json_value="$3"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Check if key already exists and remove it first
    if grep -q "\"${json_key}\"" "$file"; then
        # Remove existing key-value pair (handles both with and without trailing comma)
        sed -i "/\"${json_key}\"[[:space:]]*:[^,}]*/d" "$file"
        # Clean up any orphaned commas
        sed -i 's/,[[:space:]]*,/,/g; s/,[[:space:]]*}/}/g; s/{[[:space:]]*,/{/g' "$file"
    fi
    
    # Add the new key-value pair after the opening brace
    sed -i "1s|{|{\n  \"${json_key}\": \"${json_value}\",|" "$file"
}

# Function to safely replace commented configuration lines
safe_uncomment_and_replace() {
    local file="$1"
    local key="$2"
    local value="$3"
    local backup_suffix="${4:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Escape the value for sed
    local escaped_value
    escaped_value=$(escape_for_sed "$value")
    
    # Replace commented line with active configuration
    sed -i "s|^#${key}=.*|${key}=${escaped_value}|" "$file"
}

# Function to comment out specific patterns with sed
safe_comment_pattern() {
    local file="$1"
    local pattern="$2"
    local backup_suffix="${3:-backup}"
    
    if [ ! -f "$file" ]; then
        echo "Error: File $file does not exist" >&2
        return 1
    fi
    
    # Create backup
    cp "$file" "$file.$backup_suffix" || return 1
    
    # Comment out lines matching the pattern
    sed -i "s/^${pattern}/#&/" "$file"
}