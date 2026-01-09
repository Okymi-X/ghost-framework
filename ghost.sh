#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Bug Bounty Automation Framework
# ==============================================================================
# File: ghost.sh
# Description: Main CLI entry point and pipeline orchestrator
# Version: 1.0.0
# License: MIT
# 
# Usage: ./ghost.sh -d target.com [-m stealth|aggressive] [-h]
# 
# This is the main entry point for GHOST-FRAMEWORK. It orchestrates:
# - Dependency checking and auto-installation
# - Reconnaissance (subdomain enumeration, WAF detection)
# - Crawling (URL discovery, parameter mining)
# - Vulnerability scanning (Nuclei, XSS, SQLi)
# - Report generation
# ==============================================================================

set -o pipefail

# Framework constants
readonly GHOST_VERSION="1.1.0"
readonly GHOST_CODENAME="Phantom"

# Determine script directory (handles symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Default values
DEFAULT_MODE="stealth"
SKIP_INSTALL="false"
SKIP_RECON="false"
SKIP_CRAWL="false"
SKIP_VULN="false"

# ------------------------------------------------------------------------------
# load_config()
# Load configuration from ghost.conf
# ------------------------------------------------------------------------------
load_config() {
    local config_file="$SCRIPT_DIR/config/ghost.conf"
    
    if [ -f "$config_file" ]; then
        # shellcheck source=/dev/null
        source "$config_file"
        log_debug "Configuration loaded from $config_file"
    else
        log_warn "Configuration file not found at $config_file"
        log_info "Using default settings"
    fi
}

# ------------------------------------------------------------------------------
# load_modules()
# Source all utility and module files
# ------------------------------------------------------------------------------
load_modules() {
    # Load utilities first
    local utils_dir="$SCRIPT_DIR/utils"
    local modules_dir="$SCRIPT_DIR/modules"
    
    # Banner and colors
    if [ -f "$utils_dir/banner.sh" ]; then
        source "$utils_dir/banner.sh"
    else
        echo "Error: banner.sh not found"
        exit 1
    fi
    
    # Logger
    if [ -f "$utils_dir/logger.sh" ]; then
        source "$utils_dir/logger.sh"
    else
        echo "Error: logger.sh not found"
        exit 1
    fi
    
    # Notifications
    if [ -f "$utils_dir/notifications.sh" ]; then
        source "$utils_dir/notifications.sh"
    fi
    
    # Core modules
    if [ -f "$modules_dir/installer.sh" ]; then
        source "$modules_dir/installer.sh"
    fi
    
    if [ -f "$modules_dir/recon.sh" ]; then
        source "$modules_dir/recon.sh"
    fi
    
    if [ -f "$modules_dir/crawling.sh" ]; then
        source "$modules_dir/crawling.sh"
    fi
    
    if [ -f "$modules_dir/vulnerability.sh" ]; then
        source "$modules_dir/vulnerability.sh"
    fi
    
    # New v1.1 modules
    if [ -f "$modules_dir/secrets.sh" ]; then
        source "$modules_dir/secrets.sh"
    fi
    
    if [ -f "$modules_dir/takeover.sh" ]; then
        source "$modules_dir/takeover.sh"
    fi
    
    if [ -f "$modules_dir/portscan.sh" ]; then
        source "$modules_dir/portscan.sh"
    fi
    
    if [ -f "$modules_dir/fuzzing.sh" ]; then
        source "$modules_dir/fuzzing.sh"
    fi
    
    if [ -f "$modules_dir/screenshots.sh" ]; then
        source "$modules_dir/screenshots.sh"
    fi
    
    log_debug "All modules loaded successfully"
}

# ------------------------------------------------------------------------------
# show_usage()
# Display help information
# ------------------------------------------------------------------------------
show_usage() {
    if type print_banner &>/dev/null; then
        print_banner
    else
        echo "GHOST-FRAMEWORK v${GHOST_VERSION}"
        echo ""
    fi
    
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  -d, --domain DOMAIN     Target domain to scan (e.g., example.com)"
    echo ""
    echo "Optional:"
    echo "  -m, --mode MODE         Scan mode: stealth (default) or aggressive"
    echo "  -o, --output DIR        Output directory (default: ./results)"
    echo "  -c, --config FILE       Custom config file path"
    echo ""
    echo "Scan Control:"
    echo "  --skip-install          Skip dependency check/installation"
    echo "  --skip-recon            Skip reconnaissance phase"
    echo "  --skip-crawl            Skip crawling phase"
    echo "  --skip-vuln             Skip vulnerability scanning"
    echo "  --recon-only            Run only reconnaissance"
    echo "  --crawl-only            Run only crawling (requires prior recon)"
    echo "  --vuln-only             Run only vulnerability scan (requires prior phases)"
    echo ""
    echo "Other:"
    echo "  -v, --verbose           Enable verbose output"
    echo "  --debug                 Enable debug mode"
    echo "  -h, --help              Show this help message"
    echo "  --version               Show version information"
    echo "  --install               Only run the dependency installer"
    echo "  --test-notify           Test notification webhooks"
    echo ""
    echo "Examples:"
    echo "  $0 -d example.com"
    echo "  $0 -d example.com -m aggressive"
    echo "  $0 -d example.com --skip-vuln"
    echo "  $0 --install"
    echo ""
}

# ------------------------------------------------------------------------------
# show_version()
# Display version information
# ------------------------------------------------------------------------------
show_version() {
    echo "GHOST-FRAMEWORK v${GHOST_VERSION} (${GHOST_CODENAME})"
    echo "Bug Bounty Automation Framework"
    echo "Author: Okymi-X <ali.youssouf.etu@esmt.sn>"
    echo "https://github.com/Okymi-X/ghost-framework"
}

# ------------------------------------------------------------------------------
# parse_arguments()
# Parse command line arguments
# Arguments: All command line arguments
# ------------------------------------------------------------------------------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--domain)
                TARGET_DOMAIN="$2"
                shift 2
                ;;
            -m|--mode)
                SCAN_MODE="$2"
                shift 2
                ;;
            -o|--output)
                RESULTS_DIR="$2"
                shift 2
                ;;
            -c|--config)
                CUSTOM_CONFIG="$2"
                shift 2
                ;;
            --skip-install)
                SKIP_INSTALL="true"
                shift
                ;;
            --skip-recon)
                SKIP_RECON="true"
                shift
                ;;
            --skip-crawl)
                SKIP_CRAWL="true"
                shift
                ;;
            --skip-vuln)
                SKIP_VULN="true"
                shift
                ;;
            --recon-only)
                SKIP_CRAWL="true"
                SKIP_VULN="true"
                shift
                ;;
            --crawl-only)
                SKIP_RECON="true"
                SKIP_VULN="true"
                shift
                ;;
            --vuln-only)
                SKIP_RECON="true"
                SKIP_CRAWL="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --debug)
                DEBUG="true"
                LOG_LEVEL="DEBUG"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            --install)
                INSTALL_ONLY="true"
                shift
                ;;
            --test-notify)
                TEST_NOTIFY="true"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# validate_arguments()
# Validate required arguments are present
# ------------------------------------------------------------------------------
validate_arguments() {
    # Skip validation for certain modes
    if [ "${INSTALL_ONLY:-false}" = "true" ] || [ "${TEST_NOTIFY:-false}" = "true" ]; then
        return 0
    fi
    
    if [ -z "${TARGET_DOMAIN:-}" ]; then
        print_error "Target domain is required. Use -d or --domain"
        echo ""
        show_usage
        exit 1
    fi
    
    # Validate domain format (basic check)
    if ! echo "$TARGET_DOMAIN" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'; then
        print_warning "Domain format may be invalid: $TARGET_DOMAIN"
    fi
    
    # Validate scan mode
    SCAN_MODE="${SCAN_MODE:-$DEFAULT_MODE}"
    if [ "$SCAN_MODE" != "stealth" ] && [ "$SCAN_MODE" != "aggressive" ]; then
        print_error "Invalid scan mode: $SCAN_MODE (must be 'stealth' or 'aggressive')"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# apply_scan_mode()
# Apply settings based on selected scan mode
# ------------------------------------------------------------------------------
apply_scan_mode() {
    local mode="${SCAN_MODE:-stealth}"
    
    log_info "Scan mode: $mode"
    
    if [ "$mode" = "stealth" ]; then
        THREADS="${STEALTH_THREADS:-2}"
        RATE_LIMIT="${STEALTH_RATE_LIMIT:-10}"
        DELAY="${STEALTH_DELAY:-2}"
        TIMEOUT="${STEALTH_TIMEOUT:-30}"
        log_info "Stealth mode: $THREADS threads, ${RATE_LIMIT} req/s, ${DELAY}s delay"
    else
        THREADS="${AGGRESSIVE_THREADS:-50}"
        RATE_LIMIT="${AGGRESSIVE_RATE_LIMIT:-150}"
        DELAY="${AGGRESSIVE_DELAY:-0}"
        TIMEOUT="${AGGRESSIVE_TIMEOUT:-10}"
        log_info "Aggressive mode: $THREADS threads, ${RATE_LIMIT} req/s"
    fi
    
    # Export for use in modules
    export THREADS RATE_LIMIT DELAY TIMEOUT
}

# ------------------------------------------------------------------------------
# create_workspace()
# Create a timestamped workspace directory for results
# Returns: Path to the workspace directory
# ------------------------------------------------------------------------------
create_workspace() {
    local domain="$TARGET_DOMAIN"
    local base_dir="${RESULTS_DIR:-$SCRIPT_DIR/results}"
    local timestamp
    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    
    # Sanitize domain for directory name
    local safe_domain
    safe_domain=$(echo "$domain" | tr '.' '_' | tr -cd '[:alnum:]_-')
    
    local workspace="${base_dir}/${safe_domain}_${timestamp}"
    
    mkdir -p "$workspace"
    
    log_info "Workspace created: $workspace"
    
    echo "$workspace"
}

# ------------------------------------------------------------------------------
# generate_final_report()
# Generate final HTML/Markdown report
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
generate_final_report() {
    local workspace="$1"
    local report_file="$workspace/GHOST_REPORT.md"
    local html_report="$workspace/GHOST_REPORT.html"
    
    print_section "Generating Final Report"
    
    # Generate Markdown report
    {
        echo "# GHOST-FRAMEWORK Scan Report"
        echo ""
        echo "## Scan Information"
        echo "| Field | Value |"
        echo "|-------|-------|"
        echo "| Target | ${TARGET_DOMAIN} |"
        echo "| Scan Date | $(date '+%Y-%m-%d %H:%M:%S') |"
        echo "| Scan Mode | ${SCAN_MODE:-stealth} |"
        echo "| WAF Detected | ${IS_WAF:-false} |"
        if [ "${IS_WAF:-false}" = "true" ]; then
            echo "| WAF Provider | ${WAF_PROVIDER:-Unknown} |"
        fi
        echo ""
        
        # Reconnaissance Summary
        echo "## Reconnaissance Results"
        if [ -f "$workspace/subdomains.txt" ]; then
            echo "- **Subdomains Found:** $(wc -l < "$workspace/subdomains.txt" | tr -d ' ')"
        fi
        if [ -f "$workspace/live_hosts.txt" ]; then
            echo "- **Live Hosts:** $(wc -l < "$workspace/live_hosts.txt" | tr -d ' ')"
        fi
        echo ""
        
        # Crawling Summary
        echo "## Crawling Results"
        if [ -f "$workspace/all_urls.txt" ]; then
            echo "- **Total URLs:** $(wc -l < "$workspace/all_urls.txt" | tr -d ' ')"
        fi
        if [ -f "$workspace/params/urls_with_params.txt" ]; then
            echo "- **URLs with Parameters:** $(wc -l < "$workspace/params/urls_with_params.txt" | tr -d ' ')"
        fi
        if [ -f "$workspace/js_files.txt" ]; then
            echo "- **JavaScript Files:** $(wc -l < "$workspace/js_files.txt" | tr -d ' ')"
        fi
        echo ""
        
        # Vulnerability Summary
        echo "## Vulnerability Findings"
        echo ""
        if [ -d "$workspace/findings" ]; then
            echo "| Severity | Count |"
            echo "|----------|-------|"
            echo "| Critical | ${FINDING_COUNTS[critical]:-0} |"
            echo "| High | ${FINDING_COUNTS[high]:-0} |"
            echo "| Medium | ${FINDING_COUNTS[medium]:-0} |"
            echo "| Low | ${FINDING_COUNTS[low]:-0} |"
            echo "| Info | ${FINDING_COUNTS[info]:-0} |"
        else
            echo "No vulnerability scan was performed."
        fi
        echo ""
        
        # Files Generated
        echo "## Output Files"
        echo ""
        echo "| File | Description |"
        echo "|------|-------------|"
        [ -f "$workspace/subdomains.txt" ] && echo "| subdomains.txt | Discovered subdomains |"
        [ -f "$workspace/live_hosts.txt" ] && echo "| live_hosts.txt | Live web servers |"
        [ -f "$workspace/all_urls.txt" ] && echo "| all_urls.txt | All discovered URLs |"
        [ -f "$workspace/js_files.txt" ] && echo "| js_files.txt | JavaScript files |"
        [ -d "$workspace/params" ] && echo "| params/ | Parameter analysis |"
        [ -d "$workspace/findings" ] && echo "| findings/ | Vulnerability findings |"
        echo ""
        
        echo "---"
        echo "*Report generated by GHOST-FRAMEWORK v${GHOST_VERSION}*"
        
    } > "$report_file"
    
    log_success "Markdown report: $report_file"
    
    # Generate simple HTML report
    {
        echo "<!DOCTYPE html>"
        echo "<html><head>"
        echo "<meta charset='UTF-8'>"
        echo "<title>GHOST-FRAMEWORK Report - ${TARGET_DOMAIN}</title>"
        echo "<style>"
        echo "body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; background: #0d1117; color: #c9d1d9; }"
        echo "h1 { color: #58a6ff; border-bottom: 2px solid #30363d; padding-bottom: 10px; }"
        echo "h2 { color: #8b949e; margin-top: 30px; }"
        echo "table { border-collapse: collapse; width: 100%; margin: 15px 0; }"
        echo "th, td { border: 1px solid #30363d; padding: 10px; text-align: left; }"
        echo "th { background: #161b22; color: #58a6ff; }"
        echo "tr:nth-child(even) { background: #161b22; }"
        echo ".critical { color: #f85149; font-weight: bold; }"
        echo ".high { color: #da3633; }"
        echo ".medium { color: #d29922; }"
        echo ".low { color: #58a6ff; }"
        echo ".footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #30363d; color: #8b949e; font-size: 0.9em; }"
        echo "</style>"
        echo "</head><body>"
        echo "<h1>🔍 GHOST-FRAMEWORK Scan Report</h1>"
        
        echo "<h2>Scan Information</h2>"
        echo "<table>"
        echo "<tr><th>Field</th><th>Value</th></tr>"
        echo "<tr><td>Target</td><td>${TARGET_DOMAIN}</td></tr>"
        echo "<tr><td>Scan Date</td><td>$(date '+%Y-%m-%d %H:%M:%S')</td></tr>"
        echo "<tr><td>Scan Mode</td><td>${SCAN_MODE:-stealth}</td></tr>"
        echo "<tr><td>WAF Detected</td><td>${IS_WAF:-false}</td></tr>"
        if [ "${IS_WAF:-false}" = "true" ]; then
            echo "<tr><td>WAF Provider</td><td>${WAF_PROVIDER}</td></tr>"
        fi
        echo "</table>"
        
        echo "<h2>Vulnerability Summary</h2>"
        echo "<table>"
        echo "<tr><th>Severity</th><th>Count</th></tr>"
        echo "<tr class='critical'><td>Critical</td><td>${FINDING_COUNTS[critical]:-0}</td></tr>"
        echo "<tr class='high'><td>High</td><td>${FINDING_COUNTS[high]:-0}</td></tr>"
        echo "<tr class='medium'><td>Medium</td><td>${FINDING_COUNTS[medium]:-0}</td></tr>"
        echo "<tr class='low'><td>Low</td><td>${FINDING_COUNTS[low]:-0}</td></tr>"
        echo "<tr><td>Info</td><td>${FINDING_COUNTS[info]:-0}</td></tr>"
        echo "</table>"
        
        echo "<div class='footer'>"
        echo "Report generated by GHOST-FRAMEWORK v${GHOST_VERSION} (${GHOST_CODENAME})"
        echo "</div>"
        echo "</body></html>"
        
    } > "$html_report"
    
    log_success "HTML report: $html_report"
}

# ------------------------------------------------------------------------------
# print_summary()
# Print final summary to terminal
# Arguments: $1 = Workspace directory, $2 = Start time
# ------------------------------------------------------------------------------
print_summary() {
    local workspace="$1"
    local start_time="$2"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    print_section "Scan Complete"
    
    echo ""
    print_table_header "Metric" "Value" ""
    
    if [ -f "$workspace/subdomains.txt" ]; then
        print_table_row "Subdomains" "$(wc -l < "$workspace/subdomains.txt" | tr -d ' ')" ""
    fi
    
    if [ -f "$workspace/live_hosts.txt" ]; then
        print_table_row "Live Hosts" "$(wc -l < "$workspace/live_hosts.txt" | tr -d ' ')" ""
    fi
    
    if [ -f "$workspace/all_urls.txt" ]; then
        print_table_row "URLs Found" "$(wc -l < "$workspace/all_urls.txt" | tr -d ' ')" ""
    fi
    
    print_table_row "Duration" "${duration}s" ""
    print_table_footer
    
    echo ""
    
    # Findings summary
    local total_findings=0
    for sev in critical high medium low info; do
        total_findings=$((total_findings + ${FINDING_COUNTS[$sev]:-0}))
    done
    
    if [ "$total_findings" -gt 0 ]; then
        print_critical "Total Findings: $total_findings"
        [ "${FINDING_COUNTS[critical]:-0}" -gt 0 ] && echo -e "\033[1;31m  ├─ Critical: ${FINDING_COUNTS[critical]}\033[0m"
        [ "${FINDING_COUNTS[high]:-0}" -gt 0 ] && echo -e "\033[0;31m  ├─ High: ${FINDING_COUNTS[high]}\033[0m"
        [ "${FINDING_COUNTS[medium]:-0}" -gt 0 ] && echo -e "\033[0;33m  ├─ Medium: ${FINDING_COUNTS[medium]}\033[0m"
        [ "${FINDING_COUNTS[low]:-0}" -gt 0 ] && echo -e "\033[0;34m  ├─ Low: ${FINDING_COUNTS[low]}\033[0m"
        [ "${FINDING_COUNTS[info]:-0}" -gt 0 ] && echo "  └─ Info: ${FINDING_COUNTS[info]}"
    else
        print_info "No vulnerabilities found"
    fi
    
    echo ""
    print_success "Results saved to: $workspace"
    print_info "Reports: GHOST_REPORT.md, GHOST_REPORT.html"
}

# ------------------------------------------------------------------------------
# cleanup()
# Cleanup function for graceful exit
# ------------------------------------------------------------------------------
cleanup() {
    # Only log if logger is loaded
    if type log_info &>/dev/null; then
        log_info "Cleaning up..."
    fi
    
    # Remove temporary files if configured
    if [ "${KEEP_TEMP_FILES:-false}" = "false" ] && [ -n "${WORKSPACE:-}" ]; then
        rm -rf "${WORKSPACE}/crawl" 2>/dev/null || true
        rm -rf "${WORKSPACE}/recon" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# handle_interrupt()
# Handle SIGINT (Ctrl+C)
# ------------------------------------------------------------------------------
handle_interrupt() {
    echo ""
    if type print_warning &>/dev/null; then
        print_warning "Scan interrupted by user"
    else
        echo "Scan interrupted by user"
    fi
    cleanup
    exit 130
}

# ------------------------------------------------------------------------------
# main()
# Main entry point
# ------------------------------------------------------------------------------
main() {
    # Set up signal handlers
    trap handle_interrupt SIGINT SIGTERM
    trap cleanup EXIT
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load modules (includes banner.sh and logger.sh)
    load_modules
    
    # Load configuration
    if [ -n "${CUSTOM_CONFIG:-}" ] && [ -f "$CUSTOM_CONFIG" ]; then
        source "$CUSTOM_CONFIG"
    else
        load_config
    fi
    
    # Handle special modes
    if [ "${INSTALL_ONLY:-false}" = "true" ]; then
        print_banner
        run_installer "full"
        exit $?
    fi
    
    if [ "${TEST_NOTIFY:-false}" = "true" ]; then
        print_banner
        test_notifications
        exit $?
    fi
    
    # Validate arguments
    validate_arguments
    
    # Display banner
    print_banner
    
    # Initialize logging
    init_logging "${RESULTS_DIR:-$SCRIPT_DIR/results}/ghost_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Starting GHOST-FRAMEWORK v${GHOST_VERSION}"
    log_info "Target: $TARGET_DOMAIN"
    
    # Apply scan mode settings
    apply_scan_mode
    
    # Check dependencies if not skipped
    if [ "$SKIP_INSTALL" != "true" ]; then
        print_section "Checking Dependencies"
        run_installer "check"
        local installer_result=$?
        if [ $installer_result -ne 0 ]; then
            print_warning "Some dependencies missing. Running installer..."
            run_installer "full"
        fi
    fi
    
    # Create workspace
    WORKSPACE=$(create_workspace)
    export WORKSPACE
    
    # Record start time
    local start_time
    start_time=$(date +%s)
    
    # Phase 1: Reconnaissance
    if [ "$SKIP_RECON" != "true" ]; then
        run_recon "$TARGET_DOMAIN" "$WORKSPACE"
    else
        log_info "Skipping reconnaissance phase"
    fi
    
    # Phase 2: Subdomain Takeover Check
    if [ "$SKIP_RECON" != "true" ] && [ "${TAKEOVER_ENABLED:-true}" = "true" ]; then
        if type run_takeover_scan &>/dev/null; then
            run_takeover_scan "$WORKSPACE"
        fi
    fi
    
    # Phase 3: Port Scanning
    if [ "${PORTSCAN_ENABLED:-true}" = "true" ]; then
        if type run_port_scan &>/dev/null; then
            run_port_scan "$WORKSPACE"
        fi
    fi
    
    # Phase 4: Crawling
    if [ "$SKIP_CRAWL" != "true" ]; then
        if [ -f "$WORKSPACE/live_hosts.txt" ]; then
            run_crawling "$WORKSPACE"
        else
            log_warn "No live hosts found - skipping crawling"
        fi
    else
        log_info "Skipping crawling phase"
    fi
    
    # Phase 5: Secrets Extraction
    if [ "$SKIP_CRAWL" != "true" ] && [ "${SECRETS_SCAN_ENABLED:-true}" = "true" ]; then
        if type run_secrets_scan &>/dev/null; then
            run_secrets_scan "$WORKSPACE"
        fi
    fi
    
    # Phase 6: Directory Fuzzing
    if [ "${FUZZING_ENABLED:-true}" = "true" ]; then
        if type run_fuzzing &>/dev/null; then
            run_fuzzing "$WORKSPACE"
        fi
    fi
    
    # Phase 7: Screenshot Capture
    if [ "${SCREENSHOTS_ENABLED:-true}" = "true" ]; then
        if type run_screenshots &>/dev/null; then
            run_screenshots "$WORKSPACE"
        fi
    fi
    
    # Phase 8: Vulnerability Scanning
    if [ "$SKIP_VULN" != "true" ]; then
        run_vulnerability_scan "$WORKSPACE"
    else
        log_info "Skipping vulnerability scanning phase"
    fi
    
    # Generate final report
    generate_final_report "$WORKSPACE"
    
    # Print summary
    print_summary "$WORKSPACE" "$start_time"
    
    # Send completion notification
    notify_scan_complete "$TARGET_DOMAIN" "Scan complete. Check $WORKSPACE for results." 2>/dev/null || true
    
    log_info "GHOST-FRAMEWORK scan complete"
    
    return 0
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------
main "$@"
