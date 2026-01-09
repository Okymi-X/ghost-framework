#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Directory Fuzzing Module
# ==============================================================================
# File: modules/fuzzing.sh
# Description: Fast directory and file discovery with ffuf
# License: MIT
# Version: 1.1.0
#
# This module provides:
# - Fast directory brute-forcing with ffuf
# - Backup file detection (.bak, .old, .swp)
# - Config file discovery
# - Hidden endpoint detection
# - Custom wordlist support
# ==============================================================================

# Default wordlist paths
readonly DEFAULT_WORDLIST="/usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt"
readonly BACKUP_WORDLIST="/usr/share/wordlists/seclists/Discovery/Web-Content/common.txt"

# Interesting status codes
readonly INTERESTING_CODES="200,201,204,301,302,307,308,401,403,405,500,502,503"

# File extensions to check for backups
readonly BACKUP_EXTENSIONS=".bak .backup .old .orig .temp .tmp .swp .save .copy .1 .2 ~"

# Sensitive file patterns
readonly SENSITIVE_FILES=(
    ".git/config"
    ".git/HEAD"
    ".gitignore"
    ".env"
    ".env.local"
    ".env.production"
    ".env.backup"
    ".htaccess"
    ".htpasswd"
    "wp-config.php"
    "wp-config.php.bak"
    "config.php"
    "configuration.php"
    "settings.php"
    "database.yml"
    "config.yml"
    "config.json"
    ".aws/credentials"
    "id_rsa"
    "id_dsa"
    ".ssh/id_rsa"
    "server.key"
    "privatekey.pem"
    "web.config"
    "phpinfo.php"
    "info.php"
    "test.php"
    "debug.php"
    ".DS_Store"
    "Thumbs.db"
    "crossdomain.xml"
    "clientaccesspolicy.xml"
    "robots.txt"
    "sitemap.xml"
    "security.txt"
    ".well-known/security.txt"
    "package.json"
    "package-lock.json"
    "yarn.lock"
    "composer.json"
    "composer.lock"
    "Gemfile"
    "Gemfile.lock"
    "requirements.txt"
    "Dockerfile"
    "docker-compose.yml"
    ".dockerignore"
    "Makefile"
    "README.md"
    "CHANGELOG.md"
    ".svn/entries"
    ".svn/wc.db"
    ".hg/store/data"
    "CVS/Root"
    "CVSROOT/config"
    "backup.zip"
    "backup.tar.gz"
    "backup.sql"
    "database.sql"
    "dump.sql"
    "db.sql"
    "data.sql"
    "admin.zip"
    "source.zip"
    "www.zip"
    "web.zip"
)

# Admin paths to check
readonly ADMIN_PATHS=(
    "admin"
    "administrator"
    "admin.php"
    "admin/login"
    "admin/index.php"
    "adminpanel"
    "cpanel"
    "wp-admin"
    "wp-login.php"
    "phpmyadmin"
    "pma"
    "mysql"
    "myadmin"
    "dashboard"
    "manage"
    "manager"
    "control"
    "controlpanel"
    "webadmin"
    "siteadmin"
    "admin_area"
    "admin1"
    "admin2"
    "admin_login"
    "panel"
    "admincp"
    "moderator"
    "webmaster"
    "console"
    "server-status"
    "server-info"
)

# ------------------------------------------------------------------------------
# check_ffuf_installed()
# Check if ffuf is available
# Returns: 0 if installed, 1 if not
# ------------------------------------------------------------------------------
check_ffuf_installed() {
    if command -v ffuf &>/dev/null; then
        return 0
    fi
    
    log_error "ffuf not installed. Install with: go install github.com/ffuf/ffuf/v2@latest"
    return 1
}

# ------------------------------------------------------------------------------
# get_wordlist()
# Get wordlist path, using default if custom not specified
# Returns: Wordlist path
# ------------------------------------------------------------------------------
get_wordlist() {
    local custom_wordlist="${FUZZING_WORDLIST:-}"
    
    if [ -n "$custom_wordlist" ] && [ -f "$custom_wordlist" ]; then
        echo "$custom_wordlist"
        return
    fi
    
    if [ -f "$DEFAULT_WORDLIST" ]; then
        echo "$DEFAULT_WORDLIST"
        return
    fi
    
    if [ -f "$BACKUP_WORDLIST" ]; then
        echo "$BACKUP_WORDLIST"
        return
    fi
    
    # Generate minimal wordlist
    local temp_wordlist="/tmp/ghost_wordlist_$$.txt"
    cat > "$temp_wordlist" << 'EOF'
admin
api
backup
config
console
dashboard
debug
dev
doc
docs
download
files
git
help
images
img
include
js
lib
log
login
media
old
private
public
script
scripts
server-status
static
status
swagger
temp
test
tmp
upload
uploads
v1
v2
web
EOF
    echo "$temp_wordlist"
}

# ------------------------------------------------------------------------------
# run_ffuf_scan()
# Run ffuf directory fuzzing
# Arguments: $1 = Target URL, $2 = Wordlist, $3 = Output file
# ------------------------------------------------------------------------------
run_ffuf_scan() {
    local target="$1"
    local wordlist="$2"
    local output_file="$3"
    
    # Build ffuf command
    local ffuf_opts="-mc $INTERESTING_CODES -ac -s"  # Match codes, auto-calibrate, silent
    
    # Threads
    local threads="${FUZZING_THREADS:-50}"
    [ "${IS_WAF:-false}" = "true" ] && threads=$((threads / 4))
    ffuf_opts="$ffuf_opts -t $threads"
    
    # Rate limiting
    if [ "${IS_WAF:-false}" = "true" ]; then
        ffuf_opts="$ffuf_opts -rate 10"
    fi
    
    # Timeout
    ffuf_opts="$ffuf_opts -timeout 10"
    
    # Execute
    ffuf -u "${target}/FUZZ" -w "$wordlist" $ffuf_opts -o "${output_file}.json" -of json 2>/dev/null
    
    # Parse JSON to simple format
    if [ -f "${output_file}.json" ]; then
        jq -r '.results[] | "\(.status) \(.length) \(.url)"' "${output_file}.json" 2>/dev/null > "$output_file"
    fi
    
    return $?
}

# ------------------------------------------------------------------------------
# check_sensitive_files()
# Check for known sensitive files
# Arguments: $1 = Target URL, $2 = Output file
# ------------------------------------------------------------------------------
check_sensitive_files() {
    local target="$1"
    local output_file="$2"
    
    log_info "Checking for sensitive files..."
    
    local found=0
    
    for file in "${SENSITIVE_FILES[@]}"; do
        local url="${target}/${file}"
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 5 "$url" 2>/dev/null)
        
        if [ "$response" = "200" ]; then
            echo "[200] $url" >> "$output_file"
            found=$((found + 1))
            
            # Highlight critical files
            case "$file" in
                ".git"*|".env"*|"*config*"|"*key*"|"*password*"|"*credential*"|"*.sql")
                    echo -e "\033[1;31m[CRITICAL]\033[0m Sensitive file exposed: $url"
                    increment_finding "critical" 2>/dev/null || true
                    notify_finding "CRITICAL" "Sensitive File Exposed" "$url" "$file" 2>/dev/null &
                    ;;
                *)
                    echo -e "\033[0;33m[INFO]\033[0m Found: $url"
                    ;;
            esac
        fi
        
        # Rate limiting
        [ "${IS_WAF:-false}" = "true" ] && sleep 0.5 || sleep 0.1
        
    done
    
    log_info "Found $found sensitive files"
    return 0
}

# ------------------------------------------------------------------------------
# check_admin_paths()
# Check for admin panel paths
# Arguments: $1 = Target URL, $2 = Output file
# ------------------------------------------------------------------------------
check_admin_paths() {
    local target="$1"
    local output_file="$2"
    
    log_info "Checking for admin panels..."
    
    local found=0
    
    for path in "${ADMIN_PATHS[@]}"; do
        local url="${target}/${path}"
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 5 "$url" 2>/dev/null)
        
        case "$response" in
            200|301|302|307|308)
                echo "[$response] $url" >> "$output_file"
                found=$((found + 1))
                echo -e "\033[0;33m[ADMIN]\033[0m Found: $url ($response)"
                ;;
            401|403)
                echo "[$response] $url (protected)" >> "$output_file"
                found=$((found + 1))
                log_info "Protected admin panel: $url"
                ;;
        esac
        
        # Rate limiting
        [ "${IS_WAF:-false}" = "true" ] && sleep 0.5 || sleep 0.1
        
    done
    
    log_info "Found $found admin panels"
    return 0
}

# ------------------------------------------------------------------------------
# check_backup_files()
# Check for backup versions of known files
# Arguments: $1 = Target URL, $2 = Found files list, $3 = Output file
# ------------------------------------------------------------------------------
check_backup_files() {
    local target="$1"
    local found_files="$2"
    local output_file="$3"
    
    log_info "Checking for backup files..."
    
    if [ ! -f "$found_files" ]; then
        return 0
    fi
    
    local found=0
    
    while IFS= read -r line; do
        local file_url
        file_url=$(echo "$line" | awk '{print $NF}')
        
        [ -z "$file_url" ] && continue
        
        # Try backup extensions
        for ext in $BACKUP_EXTENSIONS; do
            local backup_url="${file_url}${ext}"
            local response
            response=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 5 "$backup_url" 2>/dev/null)
            
            if [ "$response" = "200" ]; then
                echo "[200] $backup_url" >> "$output_file"
                found=$((found + 1))
                echo -e "\033[0;33m[BACKUP]\033[0m Found: $backup_url"
            fi
        done
        
    done < <(head -50 "$found_files")  # Limit to first 50 files
    
    log_info "Found $found backup files"
    return 0
}

# ------------------------------------------------------------------------------
# check_git_exposure()
# Check for exposed .git directory and extract info
# Arguments: $1 = Target URL, $2 = Output directory
# ------------------------------------------------------------------------------
check_git_exposure() {
    local target="$1"
    local output_dir="$2"
    
    local git_url="${target}/.git/config"
    local response
    response=$(curl -s --max-time 5 "$git_url" 2>/dev/null)
    
    if echo "$response" | grep -q "\[core\]"; then
        echo -e "\033[1;31m[CRITICAL]\033[0m Git repository exposed at $target/.git/"
        
        # Save git config
        echo "$response" > "$output_dir/git_config.txt"
        
        # Try to get more files
        curl -s "${target}/.git/HEAD" > "$output_dir/git_HEAD.txt" 2>/dev/null
        curl -s "${target}/.git/index" > "$output_dir/git_index.txt" 2>/dev/null
        
        increment_finding "critical" 2>/dev/null || true
        notify_finding "CRITICAL" "Git Repository Exposed" "$target" ".git directory accessible" 2>/dev/null &
        
        return 0
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# generate_fuzzing_report()
# Generate fuzzing summary report
# Arguments: $1 = Fuzzing directory
# ------------------------------------------------------------------------------
generate_fuzzing_report() {
    local fuzzing_dir="$1"
    local report_file="$fuzzing_dir/fuzzing_summary.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Directory Fuzzing Report"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date)"
        echo ""
        
        echo "FINDINGS SUMMARY:"
        echo "─────────────────"
        
        for file in "$fuzzing_dir"/*.txt; do
            [ -f "$file" ] || continue
            local name
            name=$(basename "$file" .txt)
            local count
            count=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
            printf "%-25s %s\n" "$name:" "$count"
        done
        
    } > "$report_file"
}

# ------------------------------------------------------------------------------
# run_fuzzing()
# Main function to run directory fuzzing
# Arguments: $1 = Workspace directory
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
run_fuzzing() {
    local workspace="$1"
    
    print_section "Directory Fuzzing"
    log_info "Workspace: $workspace"
    
    # Check if enabled
    if [ "${FUZZING_ENABLED:-true}" != "true" ]; then
        log_info "Fuzzing disabled in config"
        return 0
    fi
    
    # Check prerequisites
    if ! check_ffuf_installed; then
        log_warn "Proceeding with basic checks only"
    fi
    
    # Get targets
    local targets_file="$workspace/live_hosts.txt"
    if [ ! -f "$targets_file" ] || [ ! -s "$targets_file" ]; then
        log_warn "No live hosts found"
        return 1
    fi
    
    # Create output directory
    local fuzzing_dir="$workspace/fuzzing"
    mkdir -p "$fuzzing_dir"
    
    # Get wordlist
    local wordlist
    wordlist=$(get_wordlist)
    log_info "Using wordlist: $wordlist"
    
    local target_count
    target_count=$(wc -l < "$targets_file" | tr -d ' ')
    log_info "Fuzzing $target_count targets..."
    
    # Limit targets to avoid excessive scanning
    local max_targets="${FUZZING_MAX_TARGETS:-20}"
    
    local count=0
    while IFS= read -r target; do
        [ -z "$target" ] && continue
        count=$((count + 1))
        [ "$count" -gt "$max_targets" ] && break
        
        log_info "Scanning $count/$max_targets: $target"
        
        # Create target-specific directory
        local target_hash
        target_hash=$(echo "$target" | md5sum | cut -d' ' -f1 | head -c 8)
        local target_dir="$fuzzing_dir/$target_hash"
        mkdir -p "$target_dir"
        
        # Run ffuf if available
        if command -v ffuf &>/dev/null; then
            run_ffuf_scan "$target" "$wordlist" "$target_dir/directories.txt"
        fi
        
        # Check sensitive files
        check_sensitive_files "$target" "$target_dir/sensitive_files.txt"
        
        # Check admin paths
        check_admin_paths "$target" "$target_dir/admin_panels.txt"
        
        # Check git exposure
        check_git_exposure "$target" "$target_dir"
        
        # Check backup files
        if [ -f "$target_dir/directories.txt" ]; then
            check_backup_files "$target" "$target_dir/directories.txt" "$target_dir/backup_files.txt"
        fi
        
    done < "$targets_file"
    
    # Merge all findings
    log_info "Consolidating results..."
    
    find "$fuzzing_dir" -name "sensitive_files.txt" -exec cat {} \; 2>/dev/null | sort -u > "$fuzzing_dir/all_sensitive.txt"
    find "$fuzzing_dir" -name "admin_panels.txt" -exec cat {} \; 2>/dev/null | sort -u > "$fuzzing_dir/all_admin.txt"
    find "$fuzzing_dir" -name "directories.txt" -exec cat {} \; 2>/dev/null | sort -u > "$fuzzing_dir/all_directories.txt"
    
    # Generate report
    generate_fuzzing_report "$fuzzing_dir"
    
    # Summary
    print_section "Fuzzing Complete"
    
    local sensitive_count admin_count dir_count
    sensitive_count=$(wc -l < "$fuzzing_dir/all_sensitive.txt" 2>/dev/null | tr -d ' ' || echo 0)
    admin_count=$(wc -l < "$fuzzing_dir/all_admin.txt" 2>/dev/null | tr -d ' ' || echo 0)
    dir_count=$(wc -l < "$fuzzing_dir/all_directories.txt" 2>/dev/null | tr -d ' ' || echo 0)
    
    log_info "Directories found: $dir_count"
    [ "$sensitive_count" -gt 0 ] && log_warn "Sensitive files: $sensitive_count"
    [ "$admin_count" -gt 0 ] && log_info "Admin panels: $admin_count"
    
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Directory Fuzzing Module"
    echo "Usage: source fuzzing.sh && run_fuzzing <workspace>"
fi
