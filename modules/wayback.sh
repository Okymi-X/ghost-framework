#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Wayback Machine Diff Module
# ==============================================================================
# File: modules/wayback.sh
# Description: Compare current state with historical Wayback snapshots
# License: MIT
# Version: 1.2.0
# ==============================================================================

# Wayback CDX API
readonly WAYBACK_CDX_API="http://web.archive.org/cdx/search/cdx"
readonly WAYBACK_BASE="http://web.archive.org/web"

# ------------------------------------------------------------------------------
# get_wayback_snapshots()
# Fetch list of snapshots from Wayback Machine
# Arguments: $1 = URL, $2 = Limit
# Returns: List of timestamps
# ------------------------------------------------------------------------------
get_wayback_snapshots() {
    local url="$1"
    local limit="${2:-20}"
    
    # Query CDX API
    local response
    response=$(curl -s --max-time 30 \
        "${WAYBACK_CDX_API}?url=${url}&output=json&fl=timestamp,statuscode&limit=${limit}" 2>/dev/null)
    
    # Parse JSON (skip header row)
    echo "$response" | jq -r '.[1:][]? | .[0]' 2>/dev/null
}

# ------------------------------------------------------------------------------
# get_wayback_content()
# Fetch content from Wayback snapshot
# Arguments: $1 = URL, $2 = Timestamp
# Returns: Page content
# ------------------------------------------------------------------------------
get_wayback_content() {
    local url="$1"
    local timestamp="$2"
    
    local wayback_url="${WAYBACK_BASE}/${timestamp}id_/${url}"
    
    curl -s --max-time 30 "$wayback_url" 2>/dev/null
}

# ------------------------------------------------------------------------------
# extract_links_from_page()
# Extract all links from HTML content
# Arguments: $1 = Content
# Returns: List of URLs
# ------------------------------------------------------------------------------
extract_links_from_page() {
    local content="$1"
    
    echo "$content" | \
        grep -oE 'href="[^"]+"|src="[^"]+"' | \
        sed 's/href="//;s/src="//;s/"$//' | \
        grep -v "^#\|^javascript:\|^mailto:" | \
        sort -u
}

# ------------------------------------------------------------------------------
# compare_snapshots()
# Compare two snapshots for differences
# Arguments: $1 = Old content, $2 = New content
# Returns: Diff summary
# ------------------------------------------------------------------------------
compare_snapshots() {
    local old_content="$1"
    local new_content="$2"
    
    local old_links new_links
    old_links=$(extract_links_from_page "$old_content")
    new_links=$(extract_links_from_page "$new_content")
    
    echo "=== NEW LINKS ==="
    comm -13 <(echo "$old_links" | sort) <(echo "$new_links" | sort) 2>/dev/null
    
    echo ""
    echo "=== REMOVED LINKS ==="
    comm -23 <(echo "$old_links" | sort) <(echo "$new_links" | sort) 2>/dev/null
}

# ------------------------------------------------------------------------------
# find_hidden_endpoints()
# Find endpoints that existed before but are now hidden/removed
# Arguments: $1 = Domain, $2 = Output file
# ------------------------------------------------------------------------------
find_hidden_endpoints() {
    local domain="$1"
    local output_file="$2"
    
    log_info "Searching for hidden endpoints in Wayback..."
    
    # Get all historical URLs
    local wayback_urls
    wayback_urls=$(curl -s --max-time 60 \
        "${WAYBACK_CDX_API}?url=*.${domain}/*&output=json&fl=original&collapse=urlkey&limit=1000" 2>/dev/null)
    
    if [ -z "$wayback_urls" ]; then
        log_warn "No Wayback data found for $domain"
        return 1
    fi
    
    # Parse and extract unique URLs
    echo "$wayback_urls" | jq -r '.[1:][]? | .[0]' 2>/dev/null | sort -u > "$output_file"
    
    local count
    count=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    log_info "Found $count historical URLs"
    
    return 0
}

# ------------------------------------------------------------------------------
# find_deleted_files()
# Find files that existed before but return 404 now
# Arguments: $1 = Historical URLs file, $2 = Output file
# ------------------------------------------------------------------------------
find_deleted_files() {
    local urls_file="$1"
    local output_file="$2"
    
    if [ ! -f "$urls_file" ]; then
        return 1
    fi
    
    log_info "Checking for deleted (but archived) files..."
    
    local found=0
    
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        
        # Check current status
        local status
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
        
        if [ "$status" = "404" ] || [ "$status" = "403" ]; then
            echo "[DELETED-$status] $url" >> "$output_file"
            found=$((found + 1))
            
            # These could contain sensitive info in Wayback
            log_debug "Deleted but archived: $url"
        fi
        
        # Rate limiting
        sleep 0.2
        
    done < <(head -100 "$urls_file")  # Limit checks
    
    log_info "Found $found deleted files still in Wayback"
    return 0
}

# ------------------------------------------------------------------------------
# find_sensitive_in_wayback()
# Search Wayback for sensitive file types
# Arguments: $1 = Domain, $2 = Output file
# ------------------------------------------------------------------------------
find_sensitive_in_wayback() {
    local domain="$1"
    local output_file="$2"
    
    log_info "Searching Wayback for sensitive files..."
    
    # Sensitive extensions to search
    local extensions=("sql" "bak" "config" "conf" "env" "log" "txt" "json" "xml" "yml" "yaml" "zip" "tar" "gz")
    
    for ext in "${extensions[@]}"; do
        local results
        results=$(curl -s --max-time 30 \
            "${WAYBACK_CDX_API}?url=*.${domain}/*.${ext}&output=json&fl=original&collapse=urlkey&limit=50" 2>/dev/null)
        
        if [ -n "$results" ]; then
            echo "# .${ext} files" >> "$output_file"
            echo "$results" | jq -r '.[1:][]? | .[0]' 2>/dev/null >> "$output_file"
            echo "" >> "$output_file"
        fi
        
        sleep 1  # Rate limiting
    done
}

# ------------------------------------------------------------------------------
# analyze_js_changes()
# Compare JavaScript files over time
# Arguments: $1 = JS URL, $2 = Output directory
# ------------------------------------------------------------------------------
analyze_js_changes() {
    local js_url="$1"
    local output_dir="$2"
    
    log_info "Analyzing JS changes for: $js_url"
    
    # Get snapshots
    local snapshots
    snapshots=$(get_wayback_snapshots "$js_url" 10)
    
    if [ -z "$snapshots" ]; then
        return 1
    fi
    
    # Get oldest and newest
    local oldest newest
    oldest=$(echo "$snapshots" | tail -1)
    newest=$(echo "$snapshots" | head -1)
    
    if [ -z "$oldest" ] || [ -z "$newest" ]; then
        return 1
    fi
    
    # Fetch both versions
    local old_content new_content
    old_content=$(get_wayback_content "$js_url" "$oldest")
    new_content=$(get_wayback_content "$js_url" "$newest")
    
    # Compare for secrets
    local js_base
    js_base=$(basename "$js_url")
    
    echo "=== Secrets in OLD version ===" > "$output_dir/${js_base}_diff.txt"
    echo "$old_content" | grep -oEi "(api[_-]?key|secret|token|password|auth)['\"]?\s*[:=]\s*['\"][^'\"]{10,}['\"]" >> "$output_dir/${js_base}_diff.txt"
    
    echo "" >> "$output_dir/${js_base}_diff.txt"
    echo "=== Secrets in NEW version ===" >> "$output_dir/${js_base}_diff.txt"
    echo "$new_content" | grep -oEi "(api[_-]?key|secret|token|password|auth)['\"]?\s*[:=]\s*['\"][^'\"]{10,}['\"]" >> "$output_dir/${js_base}_diff.txt"
}

# ------------------------------------------------------------------------------
# run_wayback_scan()
# Main Wayback analysis function
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_wayback_scan() {
    local workspace="$1"
    
    print_section "Wayback Machine Analysis"
    log_info "Workspace: $workspace"
    
    if [ "${WAYBACK_ENABLED:-true}" != "true" ]; then
        log_info "Wayback analysis disabled"
        return 0
    fi
    
    local wayback_dir="$workspace/wayback"
    mkdir -p "$wayback_dir"
    
    local domain="${TARGET_DOMAIN:-}"
    if [ -z "$domain" ]; then
        log_warn "No target domain set"
        return 1
    fi
    
    # Step 1: Find all historical URLs
    find_hidden_endpoints "$domain" "$wayback_dir/historical_urls.txt"
    
    # Step 2: Search for sensitive files
    find_sensitive_in_wayback "$domain" "$wayback_dir/sensitive_files.txt"
    
    # Step 3: Check for deleted files
    if [ -f "$wayback_dir/historical_urls.txt" ]; then
        find_deleted_files "$wayback_dir/historical_urls.txt" "$wayback_dir/deleted_files.txt"
    fi
    
    # Step 4: Analyze JS changes
    if [ -f "$workspace/js_files.txt" ]; then
        log_info "Analyzing JavaScript file changes..."
        mkdir -p "$wayback_dir/js_analysis"
        
        while IFS= read -r js_url; do
            [ -z "$js_url" ] && continue
            analyze_js_changes "$js_url" "$wayback_dir/js_analysis"
        done < <(head -10 "$workspace/js_files.txt")
    fi
    
    # Generate summary
    {
        echo "══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Wayback Analysis Report"
        echo "══════════════════════════════════════════════════════════"
        echo ""
        echo "Domain: $domain"
        echo "Scan Date: $(date)"
        echo ""
        
        echo "HISTORICAL URLS:"
        echo "────────────────"
        wc -l < "$wayback_dir/historical_urls.txt" 2>/dev/null | xargs echo "Total:"
        echo ""
        
        echo "SENSITIVE FILES FOUND:"
        echo "──────────────────────"
        grep -c "^http" "$wayback_dir/sensitive_files.txt" 2>/dev/null | xargs echo "Total:"
        echo ""
        
        echo "DELETED FILES (still in archive):"
        echo "──────────────────────────────────"
        cat "$wayback_dir/deleted_files.txt" 2>/dev/null | head -20
        
    } > "$wayback_dir/wayback_summary.txt"
    
    # Summary
    print_section "Wayback Scan Complete"
    
    local historical_count=0
    [ -f "$wayback_dir/historical_urls.txt" ] && \
        historical_count=$(wc -l < "$wayback_dir/historical_urls.txt" | tr -d ' ')
    
    log_info "Found $historical_count historical URLs"
    
    local deleted_count=0
    [ -f "$wayback_dir/deleted_files.txt" ] && \
        deleted_count=$(wc -l < "$wayback_dir/deleted_files.txt" | tr -d ' ')
    
    [ "$deleted_count" -gt 0 ] && log_warn "Found $deleted_count deleted files in Wayback archive"
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Wayback Machine Module"
    echo "Usage: source wayback.sh && run_wayback_scan <workspace>"
fi
