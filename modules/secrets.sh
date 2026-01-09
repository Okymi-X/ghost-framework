#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - JavaScript Secrets Extraction Module
# ==============================================================================
# File: modules/secrets.sh
# Description: Extract API keys, tokens, and sensitive data from JS files
# License: MIT
# Version: 1.1.0
# 
# This module scans JavaScript files for:
# - API keys (AWS, Google, Stripe, Twilio, etc.)
# - Access tokens and secrets
# - Hidden API endpoints
# - Internal URLs and paths
# - Hardcoded credentials
# ==============================================================================

# Secret patterns with names and regex
declare -A SECRET_PATTERNS=(
    # Cloud Provider Keys
    ["AWS_ACCESS_KEY"]='AKIA[0-9A-Z]{16}'
    ["AWS_SECRET_KEY"]='"[A-Za-z0-9/+=]{40}"'
    ["GOOGLE_API_KEY"]='AIza[0-9A-Za-z_-]{35}'
    ["GOOGLE_OAUTH"]='[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com'
    ["FIREBASE_KEY"]='AAAA[A-Za-z0-9_-]{7}:[A-Za-z0-9_-]{140}'
    
    # Payment Providers
    ["STRIPE_SECRET"]='sk_live_[0-9a-zA-Z]{24}'
    ["STRIPE_PUBLISHABLE"]='pk_live_[0-9a-zA-Z]{24}'
    ["PAYPAL_BRAINTREE"]='access_token\$production\$[0-9a-z]{16}\$[0-9a-f]{32}'
    ["SQUARE_TOKEN"]='sq0atp-[0-9A-Za-z_-]{22}'
    
    # Communication APIs
    ["TWILIO_API_KEY"]='SK[0-9a-fA-F]{32}'
    ["TWILIO_SID"]='AC[a-zA-Z0-9_-]{32}'
    ["SENDGRID_API"]='SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}'
    ["MAILGUN_API"]='key-[0-9a-zA-Z]{32}'
    ["MAILCHIMP_API"]='[0-9a-f]{32}-us[0-9]{2}'
    
    # Social Media
    ["FACEBOOK_TOKEN"]='EAACEdEose0cBA[0-9A-Za-z]+'
    ["TWITTER_TOKEN"]='[1-9][0-9]+-[0-9a-zA-Z]{40}'
    ["TWITTER_SECRET"]='[tT]witter.*['\''"][0-9a-zA-Z]{35,44}['\''"]'
    ["SLACK_TOKEN"]='xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*'
    ["SLACK_WEBHOOK"]='https://hooks\.slack\.com/services/T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8,12}/[a-zA-Z0-9_]{24}'
    ["DISCORD_WEBHOOK"]='https://discord(app)?\.com/api/webhooks/[0-9]{17,20}/[A-Za-z0-9_-]{60,68}'
    
    # Version Control
    ["GITHUB_TOKEN"]='gh[pousr]_[A-Za-z0-9_]{36}'
    ["GITLAB_TOKEN"]='glpat-[A-Za-z0-9_-]{20}'
    ["BITBUCKET_TOKEN"]='['\''"]?[a-zA-Z0-9_-]{20,40}['\''"]?'
    
    # Database
    ["MONGODB_URI"]='mongodb(\+srv)?://[a-zA-Z0-9._%-]+:[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+/[a-zA-Z0-9_-]+'
    ["POSTGRES_URI"]='postgres(ql)?://[a-zA-Z0-9._%-]+:[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+:[0-9]+/[a-zA-Z0-9_-]+'
    ["MYSQL_URI"]='mysql://[a-zA-Z0-9._%-]+:[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+:[0-9]+/[a-zA-Z0-9_-]+'
    ["REDIS_URI"]='redis://[a-zA-Z0-9._%-:]+@[a-zA-Z0-9.-]+:[0-9]+'
    
    # Authentication
    ["JWT_TOKEN"]='eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*'
    ["BEARER_TOKEN"]='"[Bb]earer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"'
    ["BASIC_AUTH"]='[Bb]asic [A-Za-z0-9+/=]{20,}'
    ["API_KEY_GENERIC"]='[aA][pP][iI][-_]?[kK][eE][yY][\s]*[:=][\s]*['\''"][a-zA-Z0-9_-]{16,64}['\''"]'
    ["SECRET_GENERIC"]='[sS][eE][cC][rR][eE][tT][\s]*[:=][\s]*['\''"][a-zA-Z0-9_-]{16,64}['\''"]'
    ["PASSWORD_GENERIC"]='[pP][aA][sS][sS][wW][oO][rR][dD][\s]*[:=][\s]*['\''"][^'\''\"]{8,}['\''"]'
    
    # Cloud Services
    ["HEROKU_API"]='[hH]eroku.*[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    ["AZURE_KEY"]='[a-zA-Z0-9/+=]{44}'
    ["DIGITALOCEAN_TOKEN"]='dop_v1_[a-f0-9]{64}'
    ["NPM_TOKEN"]='npm_[A-Za-z0-9]{36}'
    
    # Private Keys
    ["RSA_PRIVATE_KEY"]='-----BEGIN RSA PRIVATE KEY-----'
    ["SSH_PRIVATE_KEY"]='-----BEGIN OPENSSH PRIVATE KEY-----'
    ["PGP_PRIVATE_KEY"]='-----BEGIN PGP PRIVATE KEY BLOCK-----'
    
    # API Endpoints (for discovery)
    ["API_ENDPOINT"]='/api/v[0-9]+/[a-zA-Z0-9/_-]+'
    ["INTERNAL_URL"]='https?://[a-zA-Z0-9.-]+\.(internal|local|dev|staging|test)[a-zA-Z0-9./-]*'
    ["ADMIN_ENDPOINT"]='/admin[a-zA-Z0-9/_-]*'
    ["DEBUG_ENDPOINT"]='\.(debug|test|dev|staging)[a-zA-Z0-9./-]*'
)

# Severity mapping
declare -A SECRET_SEVERITY=(
    ["AWS_ACCESS_KEY"]="CRITICAL"
    ["AWS_SECRET_KEY"]="CRITICAL"
    ["GOOGLE_API_KEY"]="HIGH"
    ["STRIPE_SECRET"]="CRITICAL"
    ["JWT_TOKEN"]="HIGH"
    ["MONGODB_URI"]="CRITICAL"
    ["RSA_PRIVATE_KEY"]="CRITICAL"
    ["SSH_PRIVATE_KEY"]="CRITICAL"
    ["PASSWORD_GENERIC"]="HIGH"
    ["API_KEY_GENERIC"]="MEDIUM"
    ["SLACK_TOKEN"]="HIGH"
    ["GITHUB_TOKEN"]="CRITICAL"
)

# ------------------------------------------------------------------------------
# download_js_files()
# Download JavaScript files for analysis
# Arguments: $1 = JS file list, $2 = Output directory
# ------------------------------------------------------------------------------
download_js_files() {
    local js_list="$1"
    local output_dir="$2"
    
    log_info "Downloading JavaScript files for analysis..."
    
    mkdir -p "$output_dir"
    
    if [ ! -f "$js_list" ] || [ ! -s "$js_list" ]; then
        log_warn "No JavaScript files to download"
        return 1
    fi
    
    local count=0
    local total
    total=$(wc -l < "$js_list" | tr -d ' ')
    
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        
        # Generate filename from URL
        local filename
        filename=$(echo "$url" | md5sum | cut -d' ' -f1).js
        
        # Download with timeout
        if curl -s -L --max-time 10 "$url" -o "$output_dir/$filename" 2>/dev/null; then
            count=$((count + 1))
        fi
        
        # Respect rate limits
        [ "${IS_WAF:-false}" = "true" ] && sleep 1
        
    done < "$js_list"
    
    log_success "Downloaded $count/$total JavaScript files"
    return 0
}

# ------------------------------------------------------------------------------
# scan_for_secrets()
# Scan files for secrets using regex patterns
# Arguments: $1 = Directory to scan, $2 = Output file
# ------------------------------------------------------------------------------
scan_for_secrets() {
    local scan_dir="$1"
    local output_file="$2"
    
    log_info "Scanning for secrets and sensitive data..."
    
    if [ ! -d "$scan_dir" ] || [ -z "$(ls -A "$scan_dir" 2>/dev/null)" ]; then
        log_warn "No files to scan"
        return 1
    fi
    
    local findings=0
    local json_output="${output_file%.txt}.json"
    
    # Initialize JSON output
    echo "[" > "$json_output"
    local first_entry=true
    
    # Scan each pattern
    for pattern_name in "${!SECRET_PATTERNS[@]}"; do
        local pattern="${SECRET_PATTERNS[$pattern_name]}"
        local severity="${SECRET_SEVERITY[$pattern_name]:-INFO}"
        
        # Search for pattern in all files
        while IFS= read -r match; do
            [ -z "$match" ] && continue
            
            local file
            local line_content
            file=$(echo "$match" | cut -d: -f1)
            line_content=$(echo "$match" | cut -d: -f2-)
            
            # Truncate long matches
            if [ ${#line_content} -gt 200 ]; then
                line_content="${line_content:0:200}..."
            fi
            
            findings=$((findings + 1))
            
            # Output to text file
            echo "[$severity] $pattern_name" >> "$output_file"
            echo "  File: $file" >> "$output_file"
            echo "  Match: $line_content" >> "$output_file"
            echo "" >> "$output_file"
            
            # Output to JSON
            if [ "$first_entry" = true ]; then
                first_entry=false
            else
                echo "," >> "$json_output"
            fi
            
            # Escape for JSON
            local escaped_match
            escaped_match=$(echo "$line_content" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')
            
            cat >> "$json_output" << EOF
  {
    "type": "$pattern_name",
    "severity": "$severity",
    "file": "$file",
    "match": "$escaped_match"
  }
EOF
            
            # Print critical/high findings immediately
            case "$severity" in
                "CRITICAL")
                    echo -e "\033[1;31m[CRITICAL]\033[0m $pattern_name found in $file"
                    increment_finding "critical" 2>/dev/null || true
                    notify_finding "CRITICAL" "Secret Exposed: $pattern_name" "$file" "$line_content" 2>/dev/null &
                    ;;
                "HIGH")
                    echo -e "\033[0;31m[HIGH]\033[0m $pattern_name found in $file"
                    increment_finding "high" 2>/dev/null || true
                    ;;
                "MEDIUM")
                    echo -e "\033[0;33m[MEDIUM]\033[0m $pattern_name found"
                    increment_finding "medium" 2>/dev/null || true
                    ;;
            esac
            
        done < <(grep -rhoE "$pattern" "$scan_dir" 2>/dev/null | head -100)
    done
    
    # Close JSON array
    echo "]" >> "$json_output"
    
    log_success "Found $findings potential secrets"
    return 0
}

# ------------------------------------------------------------------------------
# scan_inline_js()
# Scan HTML files for inline JavaScript secrets
# Arguments: $1 = URLs file, $2 = Output file
# ------------------------------------------------------------------------------
scan_inline_js() {
    local urls_file="$1"
    local output_file="$2"
    
    log_info "Scanning for inline JavaScript secrets..."
    
    if [ ! -f "$urls_file" ] || [ ! -s "$urls_file" ]; then
        return 0
    fi
    
    local count=0
    
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        
        # Fetch page and extract script content
        local content
        content=$(curl -s -L --max-time 15 "$url" 2>/dev/null)
        
        if [ -n "$content" ]; then
            # Check for inline secrets
            for pattern_name in "${!SECRET_PATTERNS[@]}"; do
                local pattern="${SECRET_PATTERNS[$pattern_name]}"
                local matches
                matches=$(echo "$content" | grep -oE "$pattern" 2>/dev/null | head -5)
                
                if [ -n "$matches" ]; then
                    local severity="${SECRET_SEVERITY[$pattern_name]:-INFO}"
                    echo "[$severity] $pattern_name in $url" >> "$output_file"
                    echo "$matches" | while read -r m; do
                        echo "  → $m" >> "$output_file"
                    done
                    count=$((count + 1))
                fi
            done
        fi
        
        # Rate limiting
        [ "${IS_WAF:-false}" = "true" ] && sleep 2 || sleep 0.5
        
    done < <(head -50 "$urls_file")  # Limit to 50 URLs
    
    log_info "Inline JS scan found $count potential issues"
}

# ------------------------------------------------------------------------------
# extract_endpoints()
# Extract API endpoints from JavaScript files
# Arguments: $1 = JS directory, $2 = Output file
# ------------------------------------------------------------------------------
extract_api_endpoints() {
    local js_dir="$1"
    local output_file="$2"
    
    log_info "Extracting API endpoints from JavaScript..."
    
    if [ ! -d "$js_dir" ]; then
        return 1
    fi
    
    {
        # API paths
        grep -rhoE '/api/v[0-9]+/[a-zA-Z0-9/_-]+' "$js_dir" 2>/dev/null
        grep -rhoE '/v[0-9]+/[a-zA-Z0-9/_-]+' "$js_dir" 2>/dev/null
        
        # GraphQL endpoints
        grep -rhoE '/graphql[a-zA-Z0-9/_-]*' "$js_dir" 2>/dev/null
        
        # REST patterns
        grep -rhoE '(GET|POST|PUT|DELETE|PATCH)\s*['\''"][^'\''\"]+['\''"]' "$js_dir" 2>/dev/null
        
        # Fetch/axios calls
        grep -rhoE 'fetch\s*\(\s*['\''"`][^'\''"`]+['\''"`]' "$js_dir" 2>/dev/null | \
            sed "s/fetch\s*(\s*['\"\`]//g; s/['\"\`]//g"
        
        grep -rhoE 'axios\.(get|post|put|delete)\s*\(\s*['\''"`][^'\''"`]+['\''"`]' "$js_dir" 2>/dev/null | \
            sed "s/axios\.[a-z]*\s*(\s*['\"\`]//g; s/['\"\`]//g"
            
    } | sort -u > "$output_file"
    
    local count
    count=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    log_success "Extracted $count API endpoints"
}

# ------------------------------------------------------------------------------
# run_secrets_scan()
# Main function to run complete secrets scanning
# Arguments: $1 = Workspace directory
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
run_secrets_scan() {
    local workspace="$1"
    
    print_section "JavaScript Secrets Extraction"
    log_info "Workspace: $workspace"
    
    # Check if enabled
    if [ "${SECRETS_SCAN_ENABLED:-true}" != "true" ]; then
        log_info "Secrets scanning disabled in config"
        return 0
    fi
    
    # Create output directory
    local secrets_dir="$workspace/secrets"
    mkdir -p "$secrets_dir"
    
    # Step 1: Download JS files if available
    local js_files="$workspace/js_files.txt"
    if [ -f "$js_files" ] && [ -s "$js_files" ]; then
        download_js_files "$js_files" "$secrets_dir/js_downloaded"
    fi
    
    # Step 2: Scan downloaded JS files
    if [ -d "$secrets_dir/js_downloaded" ]; then
        scan_for_secrets "$secrets_dir/js_downloaded" "$secrets_dir/secrets_found.txt"
    fi
    
    # Step 3: Scan inline JS in pages
    local live_urls="$workspace/live_hosts.txt"
    if [ -f "$live_urls" ]; then
        scan_inline_js "$live_urls" "$secrets_dir/inline_secrets.txt"
    fi
    
    # Step 4: Extract API endpoints
    if [ -d "$secrets_dir/js_downloaded" ]; then
        extract_api_endpoints "$secrets_dir/js_downloaded" "$secrets_dir/api_endpoints.txt"
    fi
    
    # Summary
    print_section "Secrets Scan Complete"
    
    local secrets_count=0
    [ -f "$secrets_dir/secrets_found.txt" ] && \
        secrets_count=$(grep -c '^\[' "$secrets_dir/secrets_found.txt" 2>/dev/null || echo 0)
    
    local endpoints_count=0
    [ -f "$secrets_dir/api_endpoints.txt" ] && \
        endpoints_count=$(wc -l < "$secrets_dir/api_endpoints.txt" 2>/dev/null | tr -d ' ')
    
    log_info "Secrets found: $secrets_count"
    log_info "API endpoints: $endpoints_count"
    
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Secrets Extraction Module"
    echo "Usage: source secrets.sh && run_secrets_scan <workspace>"
fi
