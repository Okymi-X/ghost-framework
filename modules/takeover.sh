#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Subdomain Takeover Detection Module
# ==============================================================================
# File: modules/takeover.sh
# Description: Detect vulnerable subdomains that can be claimed
# License: MIT
# Version: 1.1.0
#
# This module detects:
# - Dangling DNS records
# - Unclaimed cloud services (S3, Azure, Heroku, GitHub Pages, etc.)
# - CNAME pointing to non-existent resources
# ==============================================================================

# Known vulnerable fingerprints for subdomain takeover
# Format: "CNAME_PATTERN|HTTP_FINGERPRINT|SERVICE_NAME"
declare -a TAKEOVER_FINGERPRINTS=(
    # Cloud Storage
    "s3.amazonaws.com|NoSuchBucket|AWS S3"
    "s3-website|NoSuchBucket|AWS S3 Website"
    "cloudfront.net|Bad Request|AWS CloudFront"
    "elasticbeanstalk.com|404|AWS Elastic Beanstalk"
    
    # Azure
    "azurewebsites.net|404 Web Site not found|Azure Web"
    "cloudapp.net|404|Azure Cloud App"
    "azure-api.net|404|Azure API"
    "azurecontainer.io|404|Azure Container"
    "blob.core.windows.net|BlobNotFound|Azure Blob"
    "azureedge.net|404|Azure CDN"
    "trafficmanager.net|404|Azure Traffic Manager"
    
    # Google Cloud
    "storage.googleapis.com|NoSuchBucket|Google Cloud Storage"
    "appspot.com|404|Google App Engine"
    
    # GitHub
    "github.io|There isn't a GitHub Pages site here|GitHub Pages"
    "githubusercontent.com|404|GitHub Raw"
    
    # Heroku
    "herokuapp.com|No such app|Heroku"
    "herokudns.com|No such app|Heroku DNS"
    "herokussl.com|No such app|Heroku SSL"
    
    # Shopify
    "myshopify.com|Sorry, this shop is currently unavailable|Shopify"
    
    # Tumblr
    "tumblr.com|There's nothing here|Tumblr"
    
    # WordPress
    "wordpress.com|Do you want to register|WordPress"
    
    # Zendesk
    "zendesk.com|Help Center Closed|Zendesk"
    
    # Fastly
    "fastly.net|Fastly error: unknown domain|Fastly"
    
    # Pantheon
    "pantheonsite.io|404|Pantheon"
    
    # Surge
    "surge.sh|project not found|Surge"
    
    # Unbounce
    "unbouncepages.com|The requested URL was not found|Unbounce"
    
    # Fly.io
    "fly.dev|404|Fly.io"
    
    # Netlify
    "netlify.app|Not Found|Netlify"
    "netlify.com|Not Found|Netlify"
    
    # Vercel
    "vercel.app|404: NOT_FOUND|Vercel"
    "now.sh|404: NOT_FOUND|Vercel"
    
    # Cargo
    "cargocollective.com|404 Not Found|Cargo"
    
    # Help Scout
    "helpscoutdocs.com|No settings were found|HelpScout"
    
    # Ghost
    "ghost.io|The thing you were looking for is no longer here|Ghost"
    
    # Intercom
    "custom.intercom.help|This page is reserved for|Intercom"
    
    # Readme.io
    "readme.io|Project doesnt exist|Readme"
    
    # Bitbucket
    "bitbucket.io|Repository not found|Bitbucket"
    
    # Tilda
    "tilda.ws|Please renew your subscription|Tilda"
    
    # Webflow
    "webflow.io|The page you are looking for doesn't exist|Webflow"
    "proxy.webflow.com|The page you are looking for doesn't exist|Webflow"
)

# NXDOMAIN response patterns
readonly NXDOMAIN_PATTERNS="NXDOMAIN|SERVFAIL|refused|no servers"

# ------------------------------------------------------------------------------
# check_dns_status()
# Check if subdomain has valid DNS
# Arguments: $1 = Subdomain
# Returns: 0 if valid, 1 if NXDOMAIN/dangling
# ------------------------------------------------------------------------------
check_dns_status() {
    local subdomain="$1"
    
    local dns_result
    dns_result=$(dig +short "$subdomain" 2>/dev/null)
    
    if [ -z "$dns_result" ]; then
        return 1  # No DNS record
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# get_cname()
# Get CNAME record for subdomain
# Arguments: $1 = Subdomain
# Returns: CNAME target or empty
# ------------------------------------------------------------------------------
get_cname() {
    local subdomain="$1"
    dig +short CNAME "$subdomain" 2>/dev/null | head -1 | tr -d '.'
}

# ------------------------------------------------------------------------------
# check_http_fingerprint()
# Check HTTP response for takeover fingerprints
# Arguments: $1 = URL, $2 = Fingerprint to check
# Returns: 0 if vulnerable, 1 if not
# ------------------------------------------------------------------------------
check_http_fingerprint() {
    local url="$1"
    local fingerprint="$2"
    
    local response
    response=$(curl -s -L --max-time 10 -o - -w "\n%{http_code}" "$url" 2>/dev/null)
    
    if echo "$response" | grep -qi "$fingerprint"; then
        return 0  # Vulnerable
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# check_subdomain_takeover()
# Check single subdomain for takeover vulnerability
# Arguments: $1 = Subdomain, $2 = Output file
# Returns: 0 if vulnerable, 1 if not
# ------------------------------------------------------------------------------
check_subdomain_takeover() {
    local subdomain="$1"
    local output_file="$2"
    
    # Get CNAME
    local cname
    cname=$(get_cname "$subdomain")
    
    if [ -z "$cname" ]; then
        return 1  # No CNAME, skip
    fi
    
    # Check against known vulnerable patterns
    for fingerprint_entry in "${TAKEOVER_FINGERPRINTS[@]}"; do
        local cname_pattern http_fingerprint service_name
        IFS='|' read -r cname_pattern http_fingerprint service_name <<< "$fingerprint_entry"
        
        # Check if CNAME matches pattern
        if echo "$cname" | grep -qi "$cname_pattern"; then
            # Verify with HTTP check
            local vulnerable=false
            
            for proto in "https" "http"; do
                if check_http_fingerprint "${proto}://${subdomain}" "$http_fingerprint"; then
                    vulnerable=true
                    break
                fi
            done
            
            if [ "$vulnerable" = true ]; then
                echo -e "\033[1;31m[CRITICAL]\033[0m Subdomain Takeover: $subdomain"
                echo "  Service: $service_name"
                echo "  CNAME: $cname"
                echo ""
                
                # Log to file
                {
                    echo "========================================"
                    echo "SUBDOMAIN TAKEOVER DETECTED"
                    echo "========================================"
                    echo "Subdomain: $subdomain"
                    echo "Service: $service_name"
                    echo "CNAME: $cname"
                    echo "Fingerprint: $http_fingerprint"
                    echo "Date: $(date)"
                    echo ""
                } >> "$output_file"
                
                # Notify
                notify_finding "CRITICAL" "Subdomain Takeover" "$subdomain" "Service: $service_name, CNAME: $cname" 2>/dev/null &
                
                increment_finding "critical" 2>/dev/null || true
                
                return 0
            fi
        fi
    done
    
    return 1
}

# ------------------------------------------------------------------------------
# check_dangling_cname()
# Check for CNAME pointing to non-existent domain
# Arguments: $1 = Subdomain, $2 = Output file
# ------------------------------------------------------------------------------
check_dangling_cname() {
    local subdomain="$1"
    local output_file="$2"
    
    local cname
    cname=$(get_cname "$subdomain")
    
    if [ -z "$cname" ]; then
        return 1
    fi
    
    # Check if CNAME target exists
    local target_dns
    target_dns=$(dig +short "$cname" 2>/dev/null)
    
    if [ -z "$target_dns" ]; then
        # Dangling CNAME detected
        echo -e "\033[0;33m[HIGH]\033[0m Dangling CNAME: $subdomain → $cname (NXDOMAIN)"
        
        {
            echo "DANGLING CNAME"
            echo "Subdomain: $subdomain"
            echo "CNAME Target: $cname"
            echo "Status: Target does not resolve"
            echo ""
        } >> "$output_file"
        
        increment_finding "high" 2>/dev/null || true
        return 0
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# run_nuclei_takeover()
# Run Nuclei with takeover templates
# Arguments: $1 = Subdomains file, $2 = Output file
# ------------------------------------------------------------------------------
run_nuclei_takeover() {
    local input_file="$1"
    local output_file="$2"
    
    if ! command -v nuclei &>/dev/null; then
        log_warn "Nuclei not installed, skipping template-based takeover scan"
        return 1
    fi
    
    log_info "Running Nuclei takeover templates..."
    
    # Get thread count (WAF-aware)
    local threads="${NUCLEI_THREADS:-25}"
    [ "${IS_WAF:-false}" = "true" ] && threads=$((threads / 4))
    
    # Run Nuclei with takeover tag
    nuclei -l "$input_file" \
        -t takeovers/ \
        -silent \
        -c "$threads" \
        -o "$output_file" 2>/dev/null
    
    local count
    count=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    
    if [ "$count" -gt 0 ]; then
        log_critical "Nuclei found $count takeover vulnerabilities!"
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# run_subjack()
# Run subjack tool for takeover detection
# Arguments: $1 = Subdomains file, $2 = Output file
# ------------------------------------------------------------------------------
run_subjack() {
    local input_file="$1"
    local output_file="$2"
    
    if ! command -v subjack &>/dev/null; then
        log_debug "subjack not installed, skipping"
        return 1
    fi
    
    log_info "Running subjack..."
    
    subjack -w "$input_file" -ssl -o "$output_file" -t 10 -timeout 30 2>/dev/null
    
    return 0
}

# ------------------------------------------------------------------------------
# generate_takeover_report()
# Generate summary report
# Arguments: $1 = Takeover directory
# ------------------------------------------------------------------------------
generate_takeover_report() {
    local takeover_dir="$1"
    local report_file="$takeover_dir/takeover_summary.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Subdomain Takeover Report"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date)"
        echo ""
        
        echo "CONFIRMED TAKEOVERS:"
        echo "────────────────────"
        if [ -f "$takeover_dir/vulnerable.txt" ]; then
            grep -c "SUBDOMAIN TAKEOVER" "$takeover_dir/vulnerable.txt" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
        echo ""
        
        echo "DANGLING CNAMES:"
        echo "────────────────"
        if [ -f "$takeover_dir/dangling.txt" ]; then
            grep -c "DANGLING CNAME" "$takeover_dir/dangling.txt" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
        echo ""
        
        echo "NUCLEI FINDINGS:"
        echo "────────────────"
        if [ -f "$takeover_dir/nuclei_takeover.txt" ]; then
            wc -l < "$takeover_dir/nuclei_takeover.txt" 2>/dev/null || echo "0"
        else
            echo "0"
        fi
        
    } > "$report_file"
}

# ------------------------------------------------------------------------------
# run_takeover_scan()
# Main function to run subdomain takeover detection
# Arguments: $1 = Workspace directory
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
run_takeover_scan() {
    local workspace="$1"
    
    print_section "Subdomain Takeover Detection"
    log_info "Workspace: $workspace"
    
    # Check if enabled
    if [ "${TAKEOVER_ENABLED:-true}" != "true" ]; then
        log_info "Takeover detection disabled in config"
        return 0
    fi
    
    # Check for subdomains file
    local subdomains_file="$workspace/subdomains.txt"
    if [ ! -f "$subdomains_file" ] || [ ! -s "$subdomains_file" ]; then
        log_warn "No subdomains file found"
        return 1
    fi
    
    # Create output directory
    local takeover_dir="$workspace/takeover"
    mkdir -p "$takeover_dir"
    
    local subdomain_count
    subdomain_count=$(wc -l < "$subdomains_file" | tr -d ' ')
    log_info "Checking $subdomain_count subdomains..."
    
    local vulnerable_count=0
    local dangling_count=0
    
    # Step 1: Manual fingerprint checking
    log_info "Checking known vulnerable services..."
    
    while IFS= read -r subdomain; do
        [ -z "$subdomain" ] && continue
        
        # Check for takeover
        if check_subdomain_takeover "$subdomain" "$takeover_dir/vulnerable.txt"; then
            vulnerable_count=$((vulnerable_count + 1))
        fi
        
        # Check for dangling CNAME
        if check_dangling_cname "$subdomain" "$takeover_dir/dangling.txt"; then
            dangling_count=$((dangling_count + 1))
        fi
        
        # Rate limiting
        [ "${IS_WAF:-false}" = "true" ] && sleep 1 || sleep 0.2
        
    done < "$subdomains_file"
    
    # Step 2: Run Nuclei takeover templates
    run_nuclei_takeover "$subdomains_file" "$takeover_dir/nuclei_takeover.txt"
    
    # Step 3: Run subjack if available
    run_subjack "$subdomains_file" "$takeover_dir/subjack_results.txt"
    
    # Generate report
    generate_takeover_report "$takeover_dir"
    
    # Summary
    print_section "Takeover Scan Complete"
    
    if [ "$vulnerable_count" -gt 0 ]; then
        echo -e "\033[1;31m[CRITICAL] Found $vulnerable_count subdomain takeover vulnerabilities!\033[0m"
    else
        log_info "No takeover vulnerabilities found"
    fi
    
    if [ "$dangling_count" -gt 0 ]; then
        echo -e "\033[0;33m[HIGH] Found $dangling_count dangling CNAME records\033[0m"
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Subdomain Takeover Module"
    echo "Usage: source takeover.sh && run_takeover_scan <workspace>"
fi
