#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - GitHub Dorking Module
# ==============================================================================
# File: modules/github.sh
# Description: Search GitHub for exposed secrets and sensitive information
# License: MIT
# Version: 1.2.0
# ==============================================================================

# GitHub API endpoint
readonly GITHUB_API="https://api.github.com"

# Dork queries for finding secrets
declare -a GITHUB_DORKS=(
    # Credentials
    "password"
    "secret"
    "api_key"
    "apikey"
    "access_token"
    "auth_token"
    "credentials"
    "private_key"
    
    # AWS
    "aws_access_key_id"
    "aws_secret_access_key"
    "AKIA"
    
    # Database
    "db_password"
    "database_url"
    "mongodb_uri"
    "postgres"
    "mysql"
    
    # Cloud
    "firebase"
    "heroku"
    "digitalocean"
    
    # Config files
    "filename:.env"
    "filename:.npmrc"
    "filename:config"
    "filename:settings"
    "filename:credentials"
    
    # Extensions
    "extension:pem"
    "extension:key"
    "extension:sql"
    "extension:json"
)

# ------------------------------------------------------------------------------
# check_github_token()
# Verify GitHub token is set
# Returns: 0 if set, 1 if not
# ------------------------------------------------------------------------------
check_github_token() {
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log_warn "GITHUB_TOKEN not set - rate limits will apply"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# github_search()
# Perform GitHub code search
# Arguments: $1 = Query, $2 = Domain filter
# Returns: JSON results
# ------------------------------------------------------------------------------
github_search() {
    local query="$1"
    local domain="$2"
    
    local full_query="$query $domain"
    local encoded_query
    encoded_query=$(echo "$full_query" | sed 's/ /+/g; s/:/%3A/g')
    
    local response
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        response=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "${GITHUB_API}/search/code?q=${encoded_query}&per_page=100" 2>/dev/null)
    else
        response=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API}/search/code?q=${encoded_query}&per_page=100" 2>/dev/null)
    fi
    
    echo "$response"
}

# ------------------------------------------------------------------------------
# parse_github_results()
# Parse GitHub search results
# Arguments: $1 = JSON response, $2 = Query, $3 = Output file
# ------------------------------------------------------------------------------
parse_github_results() {
    local json="$1"
    local query="$2"
    local output_file="$3"
    
    if ! command -v jq &>/dev/null; then
        echo "$json" >> "$output_file"
        return
    fi
    
    local count
    count=$(echo "$json" | jq -r '.total_count // 0' 2>/dev/null)
    
    if [ "$count" -gt 0 ]; then
        echo "# Query: $query - Found: $count results" >> "$output_file"
        
        echo "$json" | jq -r '.items[]? | "[\(.repository.full_name)] \(.html_url)"' 2>/dev/null >> "$output_file"
        echo "" >> "$output_file"
    fi
}

# ------------------------------------------------------------------------------
# search_organization()
# Search within a GitHub organization
# Arguments: $1 = Organization name, $2 = Output file
# ------------------------------------------------------------------------------
search_organization() {
    local org="$1"
    local output_file="$2"
    
    log_info "Searching GitHub organization: $org"
    
    # Get organization repos
    local repos
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        repos=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "${GITHUB_API}/orgs/${org}/repos?per_page=100" 2>/dev/null)
    else
        repos=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API}/orgs/${org}/repos?per_page=100" 2>/dev/null)
    fi
    
    if command -v jq &>/dev/null; then
        echo "# Organization: $org" >> "$output_file"
        echo "$repos" | jq -r '.[]? | "[\(.name)] \(.html_url) - \(.description // "No description")"' 2>/dev/null >> "$output_file"
    fi
}

# ------------------------------------------------------------------------------
# search_user()
# Search GitHub user repositories
# Arguments: $1 = Username, $2 = Output file
# ------------------------------------------------------------------------------
search_user() {
    local user="$1"
    local output_file="$2"
    
    log_info "Searching GitHub user: $user"
    
    # Get user repos
    local repos
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        repos=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "${GITHUB_API}/users/${user}/repos?per_page=100" 2>/dev/null)
    else
        repos=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API}/users/${user}/repos?per_page=100" 2>/dev/null)
    fi
    
    if command -v jq &>/dev/null; then
        echo "# User: $user" >> "$output_file"
        echo "$repos" | jq -r '.[]? | "[\(.name)] \(.html_url)"' 2>/dev/null >> "$output_file"
    fi
}

# ------------------------------------------------------------------------------
# search_domain_dorks()
# Run all dork queries against a domain
# Arguments: $1 = Domain, $2 = Output directory
# ------------------------------------------------------------------------------
search_domain_dorks() {
    local domain="$1"
    local output_dir="$2"
    
    log_info "Running GitHub dorks for $domain..."
    
    local total_findings=0
    local dork_count=${#GITHUB_DORKS[@]}
    local current=0
    
    for dork in "${GITHUB_DORKS[@]}"; do
        current=$((current + 1))
        log_debug "[$current/$dork_count] Searching: $dork"
        
        local result
        result=$(github_search "$dork" "$domain")
        
        # Check for rate limiting
        if echo "$result" | grep -q "rate limit"; then
            log_warn "GitHub rate limit reached - pausing..."
            sleep 60
            result=$(github_search "$dork" "$domain")
        fi
        
        parse_github_results "$result" "$dork $domain" "$output_dir/dork_results.txt"
        
        # Respect rate limits
        sleep 2
    done
    
    # Count findings
    if [ -f "$output_dir/dork_results.txt" ]; then
        total_findings=$(grep -c "github.com" "$output_dir/dork_results.txt" 2>/dev/null || echo 0)
    fi
    
    log_info "GitHub dorking found $total_findings results"
}

# ------------------------------------------------------------------------------
# search_gists()
# Search GitHub Gists for secrets
# Arguments: $1 = Search term, $2 = Output file
# ------------------------------------------------------------------------------
search_gists() {
    local search_term="$1"
    local output_file="$2"
    
    log_info "Searching GitHub Gists..."
    
    local response
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        response=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "${GITHUB_API}/gists/public?per_page=100" 2>/dev/null)
    else
        response=$(curl -s --max-time 30 \
            -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API}/gists/public?per_page=100" 2>/dev/null)
    fi
    
    if command -v jq &>/dev/null; then
        echo "# Public Gists with keyword matches" >> "$output_file"
        echo "$response" | jq -r ".[]? | select(.description | contains(\"$search_term\")?) | .html_url" 2>/dev/null >> "$output_file"
    fi
}

# ------------------------------------------------------------------------------
# analyze_findings()
# Analyze and categorize GitHub findings
# Arguments: $1 = Results directory
# ------------------------------------------------------------------------------
analyze_findings() {
    local results_dir="$1"
    local analysis_file="$results_dir/analysis.txt"
    
    if [ ! -f "$results_dir/dork_results.txt" ]; then
        return
    fi
    
    log_info "Analyzing GitHub findings..."
    
    {
        echo "══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - GitHub Dorking Analysis"
        echo "══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date)"
        echo ""
        
        echo "HIGH PRIORITY (Credentials/Keys):"
        echo "──────────────────────────────────"
        grep -iE "(password|secret|api_key|access_token|private_key)" "$results_dir/dork_results.txt" 2>/dev/null | head -20
        echo ""
        
        echo "MEDIUM PRIORITY (Config Files):"
        echo "────────────────────────────────"
        grep -iE "(\.env|config|settings|credentials)" "$results_dir/dork_results.txt" 2>/dev/null | head -20
        echo ""
        
        echo "REPOSITORIES FOUND:"
        echo "───────────────────"
        grep -oE "\[.*\]" "$results_dir/dork_results.txt" 2>/dev/null | sort -u | head -30
        
    } > "$analysis_file"
}

# ------------------------------------------------------------------------------
# run_github_scan()
# Main function for GitHub dorking
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_github_scan() {
    local workspace="$1"
    
    print_section "GitHub Dorking"
    log_info "Workspace: $workspace"
    
    if [ "${GITHUB_DORK_ENABLED:-true}" != "true" ]; then
        log_info "GitHub dorking disabled in config"
        return 0
    fi
    
    local github_dir="$workspace/github"
    mkdir -p "$github_dir"
    
    check_github_token
    
    # Step 1: Search with domain dorks
    if [ -n "${TARGET_DOMAIN:-}" ]; then
        search_domain_dorks "$TARGET_DOMAIN" "$github_dir"
    fi
    
    # Step 2: Extract org/user from domain if possible
    local org_name
    org_name=$(echo "${TARGET_DOMAIN:-}" | sed 's/\.[^.]*$//' | tr '.' '-')
    
    if [ -n "$org_name" ]; then
        search_organization "$org_name" "$github_dir/org_repos.txt"
        search_user "$org_name" "$github_dir/user_repos.txt"
    fi
    
    # Step 3: Search Gists
    if [ -n "${TARGET_DOMAIN:-}" ]; then
        search_gists "$TARGET_DOMAIN" "$github_dir/gists.txt"
    fi
    
    # Step 4: Analyze findings
    analyze_findings "$github_dir"
    
    # Summary
    print_section "GitHub Scan Complete"
    
    local findings_count=0
    [ -f "$github_dir/dork_results.txt" ] && \
        findings_count=$(grep -c "github.com" "$github_dir/dork_results.txt" 2>/dev/null || echo 0)
    
    if [ "$findings_count" -gt 0 ]; then
        log_warn "Found $findings_count GitHub references to review"
        increment_finding "info" 2>/dev/null || true
    else
        log_info "No significant GitHub findings"
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK GitHub Dorking Module"
    echo "Usage: source github.sh && run_github_scan <workspace>"
fi
