#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Reconnaissance Module
# ==============================================================================
# File: modules/recon.sh
# Description: Subdomain enumeration, DNS resolution, and WAF/CDN detection
# License: MIT
# 
# This module handles the passive reconnaissance phase:
# - Subdomain discovery using multiple sources
# - DNS resolution and filtering for live hosts
# - WAF/CDN detection to adapt scanning behavior
# ==============================================================================

# WAF detection flag - exported for other modules
export IS_WAF="false"
export WAF_PROVIDER=""

# Known CDN/WAF CNAME patterns
declare -A WAF_PATTERNS=(
    ["cloudflare"]="cloudflare.com cloudflare-dns.com"
    ["akamai"]="akamai.net akamaitechnologies.com akamaiedge.net"
    ["incapsula"]="incapdns.net incapsula.com imperva.com"
    ["cloudfront"]="cloudfront.net"
    ["sucuri"]="sucuri.net sucuricdn.net"
    ["fastly"]="fastly.net fastlylb.net"
    ["maxcdn"]="maxcdn.com stackpathdns.com"
    ["ddos-guard"]="ddos-guard.net"
    ["stackpath"]="stackpath.net hwcdn.net"
)

# Known WAF HTTP headers (exported for external use)
export WAF_HEADERS="cf-ray server:cloudflare x-sucuri-id x-cdn akamai-origin-hop x-akamai-transformed"

# ------------------------------------------------------------------------------
# detect_waf_cname()
# Check CNAME records for known WAF/CDN providers
# Arguments: $1 = Domain to check
# Returns: 0 if WAF detected, 1 if not
# Sets: IS_WAF, WAF_PROVIDER global variables
# ------------------------------------------------------------------------------
detect_waf_cname() {
    local domain="$1"
    
    log_info "Checking CNAME records for WAF/CDN indicators..."
    
    # Get CNAME records
    local cname_records
    cname_records=$(dig +short CNAME "$domain" 2>/dev/null)
    
    # Also check the www subdomain
    local www_cname
    www_cname=$(dig +short CNAME "www.$domain" 2>/dev/null)
    
    local all_cnames="$cname_records $www_cname"
    
    if [ -z "$all_cnames" ]; then
        log_debug "No CNAME records found"
        return 1
    fi
    
    log_debug "CNAME records: $all_cnames"
    
    # Check against known WAF patterns
    for provider in "${!WAF_PATTERNS[@]}"; do
        for pattern in ${WAF_PATTERNS[$provider]}; do
            if echo "$all_cnames" | grep -qi "$pattern"; then
                IS_WAF="true"
                WAF_PROVIDER="$provider"
                export IS_WAF WAF_PROVIDER
                log_warn "WAF/CDN Detected: $provider (pattern: $pattern)"
                return 0
            fi
        done
    done
    
    return 1
}

# ------------------------------------------------------------------------------
# detect_waf_headers()
# Check HTTP response headers for WAF indicators
# Arguments: $1 = URL to check
# Returns: 0 if WAF detected, 1 if not
# ------------------------------------------------------------------------------
detect_waf_headers() {
    local url="$1"
    
    log_info "Checking HTTP headers for WAF indicators..."
    
    local headers
    headers=$(curl -s -I -L --max-time 10 "$url" 2>/dev/null | tr -d '\r')
    
    if [ -z "$headers" ]; then
        log_debug "Could not fetch headers"
        return 1
    fi
    
    # Check for Cloudflare
    if echo "$headers" | grep -qi "cf-ray\|cloudflare"; then
        IS_WAF="true"
        WAF_PROVIDER="cloudflare"
        export IS_WAF WAF_PROVIDER
        log_warn "WAF Detected via headers: Cloudflare"
        return 0
    fi
    
    # Check for Akamai
    if echo "$headers" | grep -qi "akamai\|x-akamai"; then
        IS_WAF="true"
        WAF_PROVIDER="akamai"
        export IS_WAF WAF_PROVIDER
        log_warn "WAF Detected via headers: Akamai"
        return 0
    fi
    
    # Check for Sucuri
    if echo "$headers" | grep -qi "x-sucuri-id\|sucuri"; then
        IS_WAF="true"
        WAF_PROVIDER="sucuri"
        export IS_WAF WAF_PROVIDER
        log_warn "WAF Detected via headers: Sucuri"
        return 0
    fi
    
    # Check for Incapsula/Imperva
    if echo "$headers" | grep -qi "incap\|imperva"; then
        IS_WAF="true"
        WAF_PROVIDER="incapsula"
        export IS_WAF WAF_PROVIDER
        log_warn "WAF Detected via headers: Incapsula/Imperva"
        return 0
    fi
    
    log_debug "No WAF detected in headers"
    return 1
}

# ------------------------------------------------------------------------------
# run_waf_detection()
# Run complete WAF detection suite
# Arguments: $1 = Domain
# Side effects: Sets IS_WAF and WAF_PROVIDER, modifies config values
# ------------------------------------------------------------------------------
run_waf_detection() {
    local domain="$1"
    
    if [ "${WAF_DETECTION_ENABLED:-true}" != "true" ]; then
        log_info "WAF detection disabled in config"
        return
    fi
    
    print_section "WAF/CDN Detection"
    
    # Reset WAF status
    IS_WAF="false"
    WAF_PROVIDER=""
    
    # Run CNAME detection
    detect_waf_cname "$domain"
    
    # If not detected via CNAME, try HTTP headers
    if [ "$IS_WAF" = "false" ]; then
        detect_waf_headers "https://$domain"
    fi
    
    # Apply WAF adaptations if detected
    if [ "$IS_WAF" = "true" ]; then
        apply_waf_adaptations
    else
        log_success "No WAF/CDN detected - proceeding with normal scan settings"
    fi
}

# ------------------------------------------------------------------------------
# apply_waf_adaptations()
# Modify scanning parameters when WAF is detected
# ------------------------------------------------------------------------------
apply_waf_adaptations() {
    log_section "Applying WAF-Aware Adaptations"
    
    log_info "Provider: $WAF_PROVIDER"
    
    # Reduce threads if enabled
    if [ "${WAF_REDUCE_THREADS:-true}" = "true" ]; then
        local reduction="${WAF_THREAD_REDUCTION:-4}"
        THREADS=$((THREADS / reduction))
        [ "$THREADS" -lt 1 ] && THREADS=1
        log_info "Threads reduced to: $THREADS"
    fi
    
    # Increase delay if enabled
    if [ "${WAF_INCREASE_DELAY:-true}" = "true" ]; then
        local multiplier="${WAF_DELAY_MULTIPLIER:-3}"
        DELAY=$((DELAY * multiplier))
        log_info "Delay increased to: ${DELAY}s"
    fi
    
    # Disable port scanning if enabled
    if [ "${WAF_DISABLE_PORTSCAN:-true}" = "true" ]; then
        export PORTSCAN_ENABLED="false"
        log_info "Port scanning: DISABLED"
    fi
    
    # Reduce rate limit
    RATE_LIMIT=$((RATE_LIMIT / 3))
    [ "$RATE_LIMIT" -lt 5 ] && RATE_LIMIT=5
    log_info "Rate limit reduced to: $RATE_LIMIT req/s"
    
    print_warning "Scan settings adapted for WAF evasion"
}

# ------------------------------------------------------------------------------
# run_subdomain_enum()
# Enumerate subdomains using Subfinder
# Arguments: $1 = Domain, $2 = Output file
# Returns: Number of subdomains found
# ------------------------------------------------------------------------------
run_subdomain_enum() {
    local domain="$1"
    local output_file="$2"
    
    print_section "Subdomain Enumeration"
    
    log_info "Running Subfinder on $domain..."
    
    # Build subfinder command with config options
    local subfinder_cmd="subfinder -d $domain -silent"
    
    # Add threads if configured
    if [ -n "${SUBFINDER_THREADS:-}" ]; then
        subfinder_cmd="$subfinder_cmd -t $SUBFINDER_THREADS"
    fi
    
    # Add timeout if configured
    if [ -n "${SUBFINDER_TIMEOUT:-}" ]; then
        subfinder_cmd="$subfinder_cmd -timeout $SUBFINDER_TIMEOUT"
    fi
    
    # Use all sources if enabled
    if [ "${SUBFINDER_ALL_SOURCES:-true}" = "true" ]; then
        subfinder_cmd="$subfinder_cmd -all"
    fi
    
    # Execute and save results
    if $subfinder_cmd > "$output_file" 2>/dev/null; then
        local count
        count=$(wc -l < "$output_file" | tr -d ' ')
        log_success "Found $count subdomains"
        return "$count"
    else
        log_error "Subfinder execution failed"
        return 0
    fi
}

# ------------------------------------------------------------------------------
# run_dns_resolution()
# Resolve subdomains to filter live hosts
# Arguments: $1 = Input file (subdomains), $2 = Output file (resolved)
# Returns: Number of resolved hosts
# ------------------------------------------------------------------------------
run_dns_resolution() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Resolving DNS for discovered subdomains..."
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        log_warn "No subdomains to resolve"
        return 0
    fi
    
    # Use dnsx for resolution
    local threads="${THREADS:-10}"
    
    if cat "$input_file" | dnsx -silent -t "$threads" > "$output_file" 2>/dev/null; then
        local count
        count=$(wc -l < "$output_file" | tr -d ' ')
        log_success "Resolved $count live hosts"
        return "$count"
    else
        log_error "DNS resolution failed"
        # Copy input to output as fallback
        cp "$input_file" "$output_file"
        return 0
    fi
}

# ------------------------------------------------------------------------------
# run_httpx_probe()
# Probe for live HTTP/HTTPS services
# Arguments: $1 = Input file (hosts), $2 = Output file (live URLs)
# Returns: Number of live web servers
# ------------------------------------------------------------------------------
run_httpx_probe() {
    local input_file="$1"
    local output_file="$2"
    
    print_section "HTTP Probing"
    
    log_info "Probing for live web servers..."
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        log_warn "No hosts to probe"
        return 0
    fi
    
    # Build httpx command
    local httpx_opts="-silent -no-color"
    
    # Add threads
    local threads="${HTTPX_THREADS:-50}"
    httpx_opts="$httpx_opts -threads $threads"
    
    # Add timeout
    local timeout="${HTTPX_TIMEOUT:-15}"
    httpx_opts="$httpx_opts -timeout $timeout"
    
    # Follow redirects if enabled
    if [ "${HTTPX_FOLLOW_REDIRECTS:-true}" = "true" ]; then
        httpx_opts="$httpx_opts -follow-redirects"
    fi
    
    # Technology detection if enabled
    if [ "${HTTPX_TECH_DETECT:-true}" = "true" ]; then
        httpx_opts="$httpx_opts -tech-detect"
    fi
    
    # Additional useful flags
    httpx_opts="$httpx_opts -status-code -title -web-server"
    
    # Execute
    if cat "$input_file" | httpx $httpx_opts > "${output_file}.full" 2>/dev/null; then
        # Extract just URLs for further processing
        cat "${output_file}.full" | awk '{print $1}' > "$output_file"
        
        local count
        count=$(wc -l < "$output_file" | tr -d ' ')
        log_success "Found $count live web servers"
        
        # Log some stats
        if [ -f "${output_file}.full" ]; then
            log_info "Full probe results saved to ${output_file}.full"
        fi
        
        return "$count"
    else
        log_error "HTTP probing failed"
        return 0
    fi
}

# ------------------------------------------------------------------------------
# generate_recon_report()
# Generate a summary report of the reconnaissance phase
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
generate_recon_report() {
    local workspace="$1"
    local report_file="$workspace/recon_summary.txt"
    
    log_info "Generating recon summary report..."
    
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Reconnaissance Summary"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Target: ${TARGET_DOMAIN:-Unknown}"
        echo ""
        echo "───────────────────────────────────────────────────────────"
        echo "RESULTS"
        echo "───────────────────────────────────────────────────────────"
        
        # Subdomain count
        if [ -f "$workspace/subdomains.txt" ]; then
            echo "Subdomains Found:    $(wc -l < "$workspace/subdomains.txt" | tr -d ' ')"
        else
            echo "Subdomains Found:    0"
        fi
        
        # Resolved hosts
        if [ -f "$workspace/resolved.txt" ]; then
            echo "Resolved Hosts:      $(wc -l < "$workspace/resolved.txt" | tr -d ' ')"
        else
            echo "Resolved Hosts:      0"
        fi
        
        # Live web servers
        if [ -f "$workspace/live_hosts.txt" ]; then
            echo "Live Web Servers:    $(wc -l < "$workspace/live_hosts.txt" | tr -d ' ')"
        else
            echo "Live Web Servers:    0"
        fi
        
        echo ""
        echo "───────────────────────────────────────────────────────────"
        echo "WAF/CDN STATUS"
        echo "───────────────────────────────────────────────────────────"
        echo "WAF Detected:        $IS_WAF"
        if [ "$IS_WAF" = "true" ]; then
            echo "WAF Provider:        $WAF_PROVIDER"
        fi
        
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        
    } > "$report_file"
    
    log_success "Report saved to $report_file"
}

# ------------------------------------------------------------------------------
# run_recon()
# Main reconnaissance function - orchestrates all recon activities
# Arguments: $1 = Domain, $2 = Workspace directory
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
run_recon() {
    local domain="$1"
    local workspace="$2"
    
    export TARGET_DOMAIN="$domain"
    
    print_section "Starting Reconnaissance Phase"
    log_info "Target: $domain"
    log_info "Workspace: $workspace"
    
    # Create workspace subdirectory for recon
    local recon_dir="$workspace/recon"
    mkdir -p "$recon_dir"
    
    # Step 1: WAF Detection
    run_waf_detection "$domain"
    
    # Step 2: Subdomain Enumeration
    run_subdomain_enum "$domain" "$recon_dir/subdomains_raw.txt"
    
    # Add main domain to list
    echo "$domain" >> "$recon_dir/subdomains_raw.txt"
    
    # Deduplicate
    sort -u "$recon_dir/subdomains_raw.txt" > "$workspace/subdomains.txt"
    local subdomain_count
    subdomain_count=$(wc -l < "$workspace/subdomains.txt" | tr -d ' ')
    
    # Step 3: DNS Resolution
    run_dns_resolution "$workspace/subdomains.txt" "$workspace/resolved.txt"
    
    # Step 4: HTTP Probing
    run_httpx_probe "$workspace/resolved.txt" "$workspace/live_hosts.txt"
    
    # Step 5: Generate Report
    generate_recon_report "$workspace"
    
    # Summary
    print_section "Reconnaissance Complete"
    log_info "Subdomains: $subdomain_count"
    log_info "Live hosts: $(wc -l < "$workspace/live_hosts.txt" 2>/dev/null | tr -d ' ' || echo 0)"
    
    if [ "$IS_WAF" = "true" ]; then
        print_warning "WAF detected ($WAF_PROVIDER) - Scan settings adapted"
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Recon Module"
    echo "Usage: source recon.sh && run_recon <domain> <workspace>"
    echo ""
    echo "This module should be sourced from ghost.sh"
fi
