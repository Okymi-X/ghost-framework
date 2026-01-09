#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Crawling Module
# ==============================================================================
# File: modules/crawling.sh
# Description: URL extraction, web crawling, and parameter mining
# License: MIT
# 
# This module handles the crawling phase:
# - Historical URL gathering (GAU, Wayback)
# - Live crawling (Katana)
# - Parameter extraction and classification (GF patterns)
# - Static asset filtering
# ==============================================================================

# File extensions to filter out (static assets)
readonly STATIC_EXTENSIONS="jpg jpeg png gif svg ico css woff woff2 ttf eot mp4 mp3 avi mov webm pdf doc docx xls xlsx ppt zip tar gz rar 7z"

# ------------------------------------------------------------------------------
# run_gau()
# Gather historical URLs using GetAllUrls
# Arguments: $1 = Domain, $2 = Output file
# Returns: Number of URLs found
# ------------------------------------------------------------------------------
run_gau() {
    local domain="$1"
    local output_file="$2"
    
    log_info "Running GAU (GetAllUrls) for historical URL discovery..."
    
    # Build GAU command
    local gau_cmd="gau --subs $domain"
    
    # Add providers if configured
    if [ -n "${GAU_PROVIDERS:-}" ]; then
        gau_cmd="$gau_cmd --providers $GAU_PROVIDERS"
    fi
    
    # Add threads if configured
    if [ -n "${GAU_THREADS:-}" ]; then
        gau_cmd="$gau_cmd --threads $GAU_THREADS"
    fi
    
    # Execute
    if $gau_cmd > "$output_file" 2>/dev/null; then
        local count
        count=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
        log_success "GAU found $count historical URLs"
        return 0
    else
        log_warn "GAU execution failed or returned no results"
        touch "$output_file"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# run_katana()
# Crawl live websites using Katana
# Arguments: $1 = Input file (URLs), $2 = Output file
# Returns: Number of URLs discovered
# ------------------------------------------------------------------------------
run_katana() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Running Katana for live crawling..."
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        log_warn "No URLs to crawl"
        touch "$output_file"
        return 1
    fi
    
    # Build Katana command
    local katana_opts="-silent -nc"  # No color
    
    # Add depth if configured
    local depth="${KATANA_DEPTH:-3}"
    katana_opts="$katana_opts -d $depth"
    
    # Add threads if configured
    local threads="${KATANA_THREADS:-10}"
    katana_opts="$katana_opts -c $threads"
    
    # Add timeout if configured
    local timeout="${KATANA_TIMEOUT:-15}"
    katana_opts="$katana_opts -timeout $timeout"
    
    # Enable JavaScript parsing if configured
    if [ "${KATANA_JS_CRAWL:-true}" = "true" ]; then
        katana_opts="$katana_opts -js-crawl"
    fi
    
    # WAF-aware: reduce concurrency if WAF detected
    if [ "${IS_WAF:-false}" = "true" ]; then
        threads=$((threads / 2))
        [ "$threads" -lt 1 ] && threads=1
        katana_opts="$katana_opts -c $threads -delay 2"
        log_info "Katana adjusted for WAF: $threads threads with 2s delay"
    fi
    
    # Execute
    if cat "$input_file" | katana $katana_opts > "$output_file" 2>/dev/null; then
        local count
        count=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
        log_success "Katana discovered $count URLs"
        return 0
    else
        log_warn "Katana execution failed"
        touch "$output_file"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# filter_static_assets()
# Remove static asset URLs from the list
# Arguments: $1 = Input file, $2 = Output file
# Returns: Number of URLs after filtering
# ------------------------------------------------------------------------------
filter_static_assets() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Filtering static assets..."
    
    if [ ! -f "$input_file" ]; then
        touch "$output_file"
        return 0
    fi
    
    # Build grep pattern for extensions to exclude
    local pattern=""
    for ext in $STATIC_EXTENSIONS; do
        if [ -z "$pattern" ]; then
            pattern="\.$ext(\?|$)"
        else
            pattern="$pattern|\.$ext(\?|$)"
        fi
    done
    
    # Filter out static assets (case insensitive)
    grep -viE "$pattern" "$input_file" > "$output_file" 2>/dev/null || true
    
    local before after
    before=$(wc -l < "$input_file" 2>/dev/null | tr -d ' ')
    after=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    local filtered=$((before - after))
    
    log_info "Filtered $filtered static asset URLs"
    log_success "Remaining URLs: $after"
    
    echo "$after"
}

# ------------------------------------------------------------------------------
# extract_parameters()
# Extract URLs with parameters and classify them using GF patterns
# Arguments: $1 = Input file (all URLs), $2 = Output directory
# ------------------------------------------------------------------------------
extract_parameters() {
    local input_file="$1"
    local output_dir="$2"
    
    log_info "Extracting and classifying parameters..."
    
    mkdir -p "$output_dir"
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        log_warn "No URLs to analyze"
        return
    fi
    
    # Extract URLs with parameters
    grep '?' "$input_file" > "$output_dir/urls_with_params.txt" 2>/dev/null || true
    local param_count
    param_count=$(wc -l < "$output_dir/urls_with_params.txt" 2>/dev/null | tr -d ' ')
    log_info "URLs with parameters: $param_count"
    
    # Check if GF is installed
    if ! command -v gf &> /dev/null; then
        log_warn "GF not installed - skipping pattern classification"
        return
    fi
    
    # Run GF patterns for various vulnerability types
    local patterns="xss sqli ssrf ssti lfi redirect idor debug"
    
    for pattern in $patterns; do
        local pattern_file="$output_dir/${pattern}_params.txt"
        cat "$input_file" | gf "$pattern" > "$pattern_file" 2>/dev/null || true
        
        local count
        count=$(wc -l < "$pattern_file" 2>/dev/null | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            log_success "GF $pattern: $count potential targets"
        else
            rm -f "$pattern_file"  # Remove empty files
        fi
    done
}

# ------------------------------------------------------------------------------
# extract_js_files()
# Extract JavaScript file URLs for further analysis
# Arguments: $1 = Input file, $2 = Output file
# ------------------------------------------------------------------------------
extract_js_files() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Extracting JavaScript files..."
    
    if [ ! -f "$input_file" ]; then
        touch "$output_file"
        return
    fi
    
    grep -iE '\.js(\?|$)' "$input_file" | sort -u > "$output_file" 2>/dev/null || true
    
    local count
    count=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    log_info "JavaScript files found: $count"
}

# ------------------------------------------------------------------------------
# extract_endpoints()
# Use unfurl to extract unique endpoints from URLs
# Arguments: $1 = Input file, $2 = Output directory
# ------------------------------------------------------------------------------
extract_endpoints() {
    local input_file="$1"
    local output_dir="$2"
    
    log_info "Extracting unique endpoints..."
    
    if ! command -v unfurl &> /dev/null; then
        log_warn "unfurl not installed - skipping endpoint extraction"
        return
    fi
    
    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        return
    fi
    
    # Extract paths
    cat "$input_file" | unfurl paths | sort -u > "$output_dir/paths.txt" 2>/dev/null || true
    
    # Extract keys (parameter names)
    cat "$input_file" | unfurl keys | sort -u > "$output_dir/param_names.txt" 2>/dev/null || true
    
    # Extract unique domains/subdomains
    cat "$input_file" | unfurl domains | sort -u > "$output_dir/domains.txt" 2>/dev/null || true
    
    log_info "Paths: $(wc -l < "$output_dir/paths.txt" 2>/dev/null | tr -d ' ')"
    log_info "Parameter names: $(wc -l < "$output_dir/param_names.txt" 2>/dev/null | tr -d ' ')"
}

# ------------------------------------------------------------------------------
# deduplicate_urls()
# Remove duplicate URLs and normalize
# Arguments: $1 = Input file, $2 = Output file
# ------------------------------------------------------------------------------
deduplicate_urls() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Deduplicating URLs..."
    
    if [ ! -f "$input_file" ]; then
        touch "$output_file"
        return
    fi
    
    # Sort, deduplicate, and filter empty lines
    sort -u "$input_file" | grep -v '^$' > "$output_file" 2>/dev/null || true
    
    local before after
    before=$(wc -l < "$input_file" 2>/dev/null | tr -d ' ')
    after=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    
    log_info "Deduplicated: $before → $after URLs"
}

# ------------------------------------------------------------------------------
# generate_crawl_report()
# Generate a summary report of the crawling phase
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
generate_crawl_report() {
    local workspace="$1"
    local report_file="$workspace/crawl_summary.txt"
    
    log_info "Generating crawl summary report..."
    
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Crawling Summary"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Target: ${TARGET_DOMAIN:-Unknown}"
        echo ""
        echo "───────────────────────────────────────────────────────────"
        echo "URL DISCOVERY"
        echo "───────────────────────────────────────────────────────────"
        
        # Total URLs
        if [ -f "$workspace/all_urls.txt" ]; then
            echo "Total Unique URLs:   $(wc -l < "$workspace/all_urls.txt" | tr -d ' ')"
        fi
        
        # URLs with params
        if [ -f "$workspace/params/urls_with_params.txt" ]; then
            echo "URLs with Params:    $(wc -l < "$workspace/params/urls_with_params.txt" | tr -d ' ')"
        fi
        
        # JS files
        if [ -f "$workspace/js_files.txt" ]; then
            echo "JavaScript Files:    $(wc -l < "$workspace/js_files.txt" | tr -d ' ')"
        fi
        
        echo ""
        echo "───────────────────────────────────────────────────────────"
        echo "GF PATTERN MATCHES"
        echo "───────────────────────────────────────────────────────────"
        
        # List GF pattern results
        for pattern_file in "$workspace"/params/*_params.txt; do
            if [ -f "$pattern_file" ]; then
                local pattern_name
                pattern_name=$(basename "$pattern_file" | sed 's/_params.txt//')
                local count
                count=$(wc -l < "$pattern_file" | tr -d ' ')
                printf "%-20s %s\n" "$pattern_name:" "$count"
            fi
        done
        
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        
    } > "$report_file"
    
    log_success "Report saved to $report_file"
}

# ------------------------------------------------------------------------------
# run_crawling()
# Main crawling function - orchestrates all crawling activities
# Arguments: $1 = Workspace directory (must contain live_hosts.txt from recon)
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
run_crawling() {
    local workspace="$1"
    
    print_section "Starting Crawling Phase"
    log_info "Workspace: $workspace"
    
    # Verify prerequisites
    if [ ! -f "$workspace/live_hosts.txt" ]; then
        log_error "live_hosts.txt not found. Run recon phase first."
        return 1
    fi
    
    # Create crawl subdirectory
    local crawl_dir="$workspace/crawl"
    mkdir -p "$crawl_dir"
    mkdir -p "$workspace/params"
    
    local domain
    domain=$(head -1 "$workspace/live_hosts.txt" | sed 's|https\?://||' | cut -d'/' -f1)
    export TARGET_DOMAIN="$domain"
    
    # Step 1: Historical URL gathering with GAU
    run_gau "$domain" "$crawl_dir/gau_urls.txt"
    
    # Step 2: Live crawling with Katana
    run_katana "$workspace/live_hosts.txt" "$crawl_dir/katana_urls.txt"
    
    # Step 3: Merge all URLs
    log_info "Merging URL sources..."
    cat "$crawl_dir/gau_urls.txt" "$crawl_dir/katana_urls.txt" 2>/dev/null | \
        sort -u > "$crawl_dir/merged_urls.txt"
    
    # Step 4: Filter static assets
    filter_static_assets "$crawl_dir/merged_urls.txt" "$crawl_dir/filtered_urls.txt"
    
    # Step 5: Deduplicate
    deduplicate_urls "$crawl_dir/filtered_urls.txt" "$workspace/all_urls.txt"
    
    # Step 6: Extract JavaScript files
    extract_js_files "$workspace/all_urls.txt" "$workspace/js_files.txt"
    
    # Step 7: Parameter extraction and classification
    extract_parameters "$workspace/all_urls.txt" "$workspace/params"
    
    # Step 8: Endpoint extraction
    extract_endpoints "$workspace/all_urls.txt" "$workspace/params"
    
    # Step 9: Generate report
    generate_crawl_report "$workspace"
    
    # Summary
    print_section "Crawling Complete"
    local total_urls
    total_urls=$(wc -l < "$workspace/all_urls.txt" 2>/dev/null | tr -d ' ')
    log_success "Total unique URLs: $total_urls"
    
    # Notify about interesting findings
    local param_urls=0
    if [ -f "$workspace/params/urls_with_params.txt" ]; then
        param_urls=$(wc -l < "$workspace/params/urls_with_params.txt" | tr -d ' ')
    fi
    log_info "URLs with parameters: $param_urls"
    
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Crawling Module"
    echo "Usage: source crawling.sh && run_crawling <workspace>"
    echo ""
    echo "This module should be sourced from ghost.sh"
    echo "Requires: live_hosts.txt from recon phase"
fi
