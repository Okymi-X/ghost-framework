#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Custom Wordlist Generator Module
# ==============================================================================
# File: modules/wordlist.sh
# Description: Generate target-specific wordlists from reconnaissance data
# License: MIT
# Version: 1.2.0
# ==============================================================================

# ------------------------------------------------------------------------------
# extract_words_from_content()
# Extract unique words from HTML content
# Arguments: $1 = Content, $2 = Min length
# Returns: List of words
# ------------------------------------------------------------------------------
extract_words_from_content() {
    local content="$1"
    local min_length="${2:-4}"
    
    echo "$content" | \
        # Remove HTML tags
        sed 's/<[^>]*>//g' | \
        # Remove special characters, keep letters and numbers
        tr -cs 'A-Za-z0-9' '\n' | \
        # Filter by length
        awk -v min="$min_length" 'length >= min' | \
        # Lowercase
        tr '[:upper:]' '[:lower:]' | \
        # Unique
        sort -u
}

# ------------------------------------------------------------------------------
# generate_permutations()
# Generate word permutations (common patterns)
# Arguments: $1 = Base word
# ------------------------------------------------------------------------------
generate_permutations() {
    local word="$1"
    
    # Base word
    echo "$word"
    
    # Common suffixes
    for suffix in "" "1" "2" "123" "2024" "2025" "admin" "test" "dev" "prod" "backup" "old" "new" "api" "v1" "v2"; do
        echo "${word}${suffix}"
        echo "${word}_${suffix}"
        echo "${word}-${suffix}"
    done
    
    # Common prefixes
    for prefix in "admin" "test" "dev" "api" "my" "the" "new" "old"; do
        echo "${prefix}${word}"
        echo "${prefix}_${word}"
        echo "${prefix}-${word}"
    done
    
    # Case variations
    echo "${word^}"  # Capitalize first
    echo "${word^^}" # All caps
}

# ------------------------------------------------------------------------------
# extract_from_subdomains()
# Extract words from subdomain list
# Arguments: $1 = Subdomains file
# ------------------------------------------------------------------------------
extract_from_subdomains() {
    local subdomains_file="$1"
    
    if [ ! -f "$subdomains_file" ]; then
        return
    fi
    
    # Extract subdomain prefixes
    cat "$subdomains_file" | \
        # Get first part of subdomain
        cut -d. -f1 | \
        # Remove numbers-only entries
        grep -v '^[0-9]*$' | \
        # Filter short entries
        awk 'length >= 3' | \
        sort -u
}

# ------------------------------------------------------------------------------
# extract_from_urls()
# Extract words from crawled URLs
# Arguments: $1 = URLs file
# ------------------------------------------------------------------------------
extract_from_urls() {
    local urls_file="$1"
    
    if [ ! -f "$urls_file" ]; then
        return
    fi
    
    cat "$urls_file" | \
        # Extract paths
        sed 's|https\?://[^/]*||' | \
        # Split by /
        tr '/' '\n' | \
        # Remove empty and extensions
        grep -v '^\s*$' | \
        sed 's/\.[a-z]*$//' | \
        # Split by common separators
        tr '_-' '\n' | \
        # Remove query strings
        sed 's/?.*//' | \
        # Filter
        awk 'length >= 3' | \
        sort -u
}

# ------------------------------------------------------------------------------
# extract_from_javascript()
# Extract potential paths/words from JavaScript files
# Arguments: $1 = JS directory
# ------------------------------------------------------------------------------
extract_from_javascript() {
    local js_dir="$1"
    
    if [ ! -d "$js_dir" ]; then
        return
    fi
    
    # Extract paths from JS
    grep -rhoE '["\'\''][a-zA-Z0-9/_-]{3,50}["\'\'']' "$js_dir" 2>/dev/null | \
        tr -d '"\047' | \
        grep -v "^http" | \
        tr '/' '\n' | \
        awk 'length >= 3' | \
        sort -u
    
    # Extract function/variable names
    grep -rhoE '\b[a-zA-Z][a-zA-Z0-9_]{3,30}\b' "$js_dir" 2>/dev/null | \
        sort -u | head -500
}

# ------------------------------------------------------------------------------
# extract_from_params()
# Extract parameter names
# Arguments: $1 = URLs file
# ------------------------------------------------------------------------------
extract_from_params() {
    local urls_file="$1"
    
    if [ ! -f "$urls_file" ]; then
        return
    fi
    
    # Extract parameter names
    grep -oE '[?&][a-zA-Z0-9_-]+=' "$urls_file" 2>/dev/null | \
        tr -d '?&=' | \
        sort -u
}

# ------------------------------------------------------------------------------
# generate_common_patterns()
# Generate common security testing paths
# Arguments: $1 = Domain base name
# ------------------------------------------------------------------------------
generate_common_patterns() {
    local base="$1"
    
    # Admin paths
    echo "admin"
    echo "administrator"
    echo "admin/login"
    echo "admin/dashboard"
    echo "cpanel"
    echo "panel"
    echo "manage"
    echo "manager"
    echo "console"
    
    # API paths
    echo "api"
    echo "api/v1"
    echo "api/v2"
    echo "api/v3"
    echo "rest"
    echo "graphql"
    echo "swagger"
    echo "docs"
    
    # Dev/test paths
    echo "dev"
    echo "test"
    echo "staging"
    echo "beta"
    echo "demo"
    echo "debug"
    echo "phpinfo"
    echo "info"
    
    # Backup paths
    echo "backup"
    echo "backups"
    echo "bak"
    echo "old"
    echo "archive"
    echo "dump"
    
    # Config paths
    echo "config"
    echo "configuration"
    echo "settings"
    echo ".env"
    echo ".git"
    echo ".svn"
    echo ".htaccess"
    
    # User paths
    echo "user"
    echo "users"
    echo "account"
    echo "accounts"
    echo "profile"
    echo "login"
    echo "signin"
    echo "register"
    echo "signup"
    echo "logout"
    echo "password"
    echo "reset"
    
    # File paths
    echo "upload"
    echo "uploads"
    echo "files"
    echo "download"
    echo "downloads"
    echo "images"
    echo "assets"
    echo "static"
    echo "media"
    
    # Target-specific
    if [ -n "$base" ]; then
        echo "$base"
        echo "${base}-admin"
        echo "${base}-api"
        echo "${base}-dev"
        echo "${base}-staging"
        echo "${base}backup"
        echo "old${base}"
        echo "new${base}"
    fi
}

# ------------------------------------------------------------------------------
# merge_and_deduplicate()
# Merge wordlists and remove duplicates
# Arguments: $1 = Output file, $@ = Input files
# ------------------------------------------------------------------------------
merge_and_deduplicate() {
    local output="$1"
    shift
    
    cat "$@" 2>/dev/null | \
        tr '[:upper:]' '[:lower:]' | \
        grep -v '^\s*$' | \
        sort -u > "$output"
}

# ------------------------------------------------------------------------------
# run_wordlist_generator()
# Main wordlist generation function
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_wordlist_generator() {
    local workspace="$1"
    
    print_section "Custom Wordlist Generator"
    log_info "Workspace: $workspace"
    
    if [ "${WORDLIST_GENERATOR_ENABLED:-true}" != "true" ]; then
        log_info "Wordlist generator disabled"
        return 0
    fi
    
    local wordlist_dir="$workspace/wordlists"
    mkdir -p "$wordlist_dir"
    
    local domain_base=""
    if [ -n "${TARGET_DOMAIN:-}" ]; then
        domain_base=$(echo "$TARGET_DOMAIN" | sed 's/\.[^.]*$//' | tr '.' '-')
    fi
    
    log_info "Extracting words from reconnaissance data..."
    
    # Extract from subdomains
    if [ -f "$workspace/subdomains.txt" ]; then
        log_info "Extracting from subdomains..."
        extract_from_subdomains "$workspace/subdomains.txt" > "$wordlist_dir/from_subdomains.txt"
    fi
    
    # Extract from URLs
    if [ -f "$workspace/all_urls.txt" ]; then
        log_info "Extracting from URLs..."
        extract_from_urls "$workspace/all_urls.txt" > "$wordlist_dir/from_urls.txt"
    fi
    
    # Extract from JavaScript
    if [ -d "$workspace/secrets/js_downloaded" ]; then
        log_info "Extracting from JavaScript..."
        extract_from_javascript "$workspace/secrets/js_downloaded" > "$wordlist_dir/from_js.txt"
    fi
    
    # Extract parameter names
    if [ -f "$workspace/all_urls.txt" ]; then
        log_info "Extracting parameter names..."
        extract_from_params "$workspace/all_urls.txt" > "$wordlist_dir/params.txt"
    fi
    
    # Generate common patterns
    log_info "Generating common patterns..."
    generate_common_patterns "$domain_base" > "$wordlist_dir/common_patterns.txt"
    
    # Generate permutations for key words
    log_info "Generating permutations..."
    if [ -f "$wordlist_dir/from_subdomains.txt" ]; then
        head -20 "$wordlist_dir/from_subdomains.txt" | while read -r word; do
            generate_permutations "$word"
        done > "$wordlist_dir/permutations.txt"
    fi
    
    # Merge all into final wordlist
    log_info "Merging wordlists..."
    merge_and_deduplicate "$wordlist_dir/custom_wordlist.txt" \
        "$wordlist_dir/from_subdomains.txt" \
        "$wordlist_dir/from_urls.txt" \
        "$wordlist_dir/from_js.txt" \
        "$wordlist_dir/common_patterns.txt" \
        "$wordlist_dir/permutations.txt"
    
    # Create specialized wordlists
    # Directory wordlist
    grep -E '^[a-z0-9_-]+$' "$wordlist_dir/custom_wordlist.txt" | \
        head -5000 > "$wordlist_dir/directories.txt"
    
    # Parameter wordlist
    cat "$wordlist_dir/params.txt" >> "$wordlist_dir/parameters.txt"
    sort -u "$wordlist_dir/parameters.txt" -o "$wordlist_dir/parameters.txt"
    
    # Summary
    print_section "Wordlist Generation Complete"
    
    local total_words=0
    if [ -f "$wordlist_dir/custom_wordlist.txt" ]; then
        total_words=$(wc -l < "$wordlist_dir/custom_wordlist.txt" | tr -d ' ')
    fi
    
    log_success "Generated $total_words unique words"
    log_info "Custom wordlist: $wordlist_dir/custom_wordlist.txt"
    log_info "Directory wordlist: $wordlist_dir/directories.txt"
    log_info "Parameter wordlist: $wordlist_dir/parameters.txt"
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Wordlist Generator"
    echo "Usage: source wordlist.sh && run_wordlist_generator <workspace>"
fi
