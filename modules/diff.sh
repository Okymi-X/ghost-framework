#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Diff Scanner Module
# ==============================================================================
# File: modules/diff.sh
# Description: Compare scans over time to detect changes
# License: MIT
# Version: 1.3.0
# ==============================================================================

# ------------------------------------------------------------------------------
# find_previous_scan()
# Find the most recent previous scan for a domain
# Arguments: $1 = Current workspace, $2 = Target domain
# Returns: Path to previous scan or empty
# ------------------------------------------------------------------------------
find_previous_scan() {
    local current_workspace="$1"
    local domain="$2"
    
    local results_dir
    results_dir=$(dirname "$current_workspace")
    
    local domain_pattern
    domain_pattern=$(echo "$domain" | tr '.' '_')
    
    # Find all scans for this domain, sorted by date
    local previous
    previous=$(find "$results_dir" -maxdepth 1 -type d -name "${domain_pattern}*" 2>/dev/null | \
        grep -v "$(basename "$current_workspace")" | \
        sort -r | \
        head -1)
    
    echo "$previous"
}

# ------------------------------------------------------------------------------
# compare_files()
# Compare two files and show differences
# Arguments: $1 = Old file, $2 = New file, $3 = Label
# Returns: Diff output
# ------------------------------------------------------------------------------
compare_files() {
    local old_file="$1"
    local new_file="$2"
    local label="$3"
    
    if [ ! -f "$old_file" ] || [ ! -f "$new_file" ]; then
        return
    fi
    
    local added removed
    added=$(comm -13 <(sort "$old_file") <(sort "$new_file") 2>/dev/null | wc -l | tr -d ' ')
    removed=$(comm -23 <(sort "$old_file") <(sort "$new_file") 2>/dev/null | wc -l | tr -d ' ')
    
    echo "$label: +$added / -$removed"
}

# ------------------------------------------------------------------------------
# generate_diff_report()
# Generate a comprehensive diff report
# Arguments: $1 = Old workspace, $2 = New workspace, $3 = Output file
# ------------------------------------------------------------------------------
generate_diff_report() {
    local old_ws="$1"
    local new_ws="$2"
    local output="$3"
    
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "       GHOST-FRAMEWORK - Scan Comparison Report"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Previous Scan: $(basename "$old_ws")"
        echo "Current Scan:  $(basename "$new_ws")"
        echo "Generated:     $(date)"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "                        SUMMARY"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        compare_files "$old_ws/subdomains.txt" "$new_ws/subdomains.txt" "Subdomains"
        compare_files "$old_ws/live_hosts.txt" "$new_ws/live_hosts.txt" "Live Hosts"
        compare_files "$old_ws/all_urls.txt" "$new_ws/all_urls.txt" "URLs"
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "                    NEW SUBDOMAINS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [ -f "$old_ws/subdomains.txt" ] && [ -f "$new_ws/subdomains.txt" ]; then
            comm -13 <(sort "$old_ws/subdomains.txt") <(sort "$new_ws/subdomains.txt")
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "                   REMOVED SUBDOMAINS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [ -f "$old_ws/subdomains.txt" ] && [ -f "$new_ws/subdomains.txt" ]; then
            comm -23 <(sort "$old_ws/subdomains.txt") <(sort "$new_ws/subdomains.txt")
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "                     NEW LIVE HOSTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [ -f "$old_ws/live_hosts.txt" ] && [ -f "$new_ws/live_hosts.txt" ]; then
            comm -13 <(sort "$old_ws/live_hosts.txt") <(sort "$new_ws/live_hosts.txt")
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "                  NEW VULNERABILITIES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        if [ -f "$old_ws/findings/nuclei_results.txt" ] && [ -f "$new_ws/findings/nuclei_results.txt" ]; then
            comm -13 <(sort "$old_ws/findings/nuclei_results.txt") <(sort "$new_ws/findings/nuclei_results.txt")
        fi
        
    } > "$output"
}

# ------------------------------------------------------------------------------
# notify_changes()
# Send notification about changes
# Arguments: $1 = Diff report path
# ------------------------------------------------------------------------------
notify_changes() {
    local report="$1"
    
    local new_subs new_hosts
    new_subs=$(grep -A1000 "NEW SUBDOMAINS" "$report" 2>/dev/null | grep -c "^[a-z]" || echo 0)
    new_hosts=$(grep -A1000 "NEW LIVE HOSTS" "$report" 2>/dev/null | grep -c "^http" || echo 0)
    
    if [ "$new_subs" -gt 0 ] || [ "$new_hosts" -gt 0 ]; then
        local message="🔄 Scan Changes Detected!
- New Subdomains: $new_subs
- New Live Hosts: $new_hosts"
        
        notify_finding "info" "Scan Changes" "$message" "diff_scanner" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# run_diff_scan()
# Main diff scanning function
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_diff_scan() {
    local workspace="$1"
    
    print_section "Diff Scanner"
    log_info "Workspace: $workspace"
    
    if [ "${DIFF_SCAN_ENABLED:-true}" != "true" ]; then
        log_info "Diff scanning disabled"
        return 0
    fi
    
    # Find previous scan
    local previous
    previous=$(find_previous_scan "$workspace" "${TARGET_DOMAIN:-}")
    
    if [ -z "$previous" ] || [ ! -d "$previous" ]; then
        log_info "No previous scan found for comparison"
        return 0
    fi
    
    log_info "Comparing with: $(basename "$previous")"
    
    local diff_dir="$workspace/diff"
    mkdir -p "$diff_dir"
    
    # Generate report
    generate_diff_report "$previous" "$workspace" "$diff_dir/diff_report.txt"
    
    # Extract key metrics
    local new_subs=0 new_hosts=0
    
    if [ -f "$previous/subdomains.txt" ] && [ -f "$workspace/subdomains.txt" ]; then
        new_subs=$(comm -13 <(sort "$previous/subdomains.txt") <(sort "$workspace/subdomains.txt") | wc -l | tr -d ' ')
    fi
    
    if [ -f "$previous/live_hosts.txt" ] && [ -f "$workspace/live_hosts.txt" ]; then
        new_hosts=$(comm -13 <(sort "$previous/live_hosts.txt") <(sort "$workspace/live_hosts.txt") | wc -l | tr -d ' ')
    fi
    
    # Summary
    print_section "Diff Scan Complete"
    log_info "New subdomains: $new_subs"
    log_info "New live hosts: $new_hosts"
    log_info "Report: $diff_dir/diff_report.txt"
    
    # Notify on significant changes
    if [ "$new_subs" -gt 0 ] || [ "$new_hosts" -gt 0 ]; then
        log_warn "Changes detected since last scan!"
        notify_changes "$diff_dir/diff_report.txt"
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Diff Scanner"
    echo "Usage: source diff.sh && run_diff_scan <workspace>"
fi
