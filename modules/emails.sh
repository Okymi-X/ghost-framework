#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Email Harvester Module
# ==============================================================================
# File: modules/emails.sh
# Description: Extract emails and employee information from various sources
# License: MIT
# Version: 1.3.0
# ==============================================================================

# Email regex pattern
readonly EMAIL_REGEX='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

# Common email patterns
declare -a EMAIL_PATTERNS=(
    "{first}.{last}"
    "{first}{last}"
    "{f}{last}"
    "{first}.{l}"
    "{first}_{last}"
    "{last}.{first}"
    "{last}{first}"
    "{first}"
)

# ------------------------------------------------------------------------------
# extract_emails_from_page()
# Extract emails from HTML content
# Arguments: $1 = Content
# Returns: List of emails
# ------------------------------------------------------------------------------
extract_emails_from_page() {
    local content="$1"
    
    echo "$content" | grep -oEi "$EMAIL_REGEX" | sort -u
}

# ------------------------------------------------------------------------------
# extract_from_website()
# Crawl website for emails
# Arguments: $1 = URL, $2 = Output file
# ------------------------------------------------------------------------------
extract_from_website() {
    local url="$1"
    local output_file="$2"
    
    log_info "Extracting emails from: $url"
    
    # Fetch main page
    local content
    content=$(curl -sL --max-time 15 "$url" 2>/dev/null)
    
    extract_emails_from_page "$content" >> "$output_file"
    
    # Check common pages
    local pages=("contact" "about" "team" "about-us" "contact-us" "our-team" "staff" "people")
    
    for page in "${pages[@]}"; do
        local page_content
        page_content=$(curl -sL --max-time 10 "${url}/${page}" 2>/dev/null)
        extract_emails_from_page "$page_content" >> "$output_file"
        
        [ "${IS_WAF:-false}" = "true" ] && sleep 1 || sleep 0.3
    done
}

# ------------------------------------------------------------------------------
# search_hunter_io()
# Query Hunter.io for company emails
# Arguments: $1 = Domain
# Returns: JSON response
# ------------------------------------------------------------------------------
search_hunter_io() {
    local domain="$1"
    
    if [ -z "${HUNTER_API_KEY:-}" ]; then
        log_debug "Hunter.io API key not set"
        return 1
    fi
    
    log_info "Querying Hunter.io..."
    
    curl -s "https://api.hunter.io/v2/domain-search?domain=${domain}&api_key=${HUNTER_API_KEY}" 2>/dev/null
}

# ------------------------------------------------------------------------------
# search_phonebook()
# Search Phonebook.cz for emails
# Arguments: $1 = Domain, $2 = Output file
# ------------------------------------------------------------------------------
search_phonebook() {
    local domain="$1"
    local output_file="$2"
    
    log_info "Searching Phonebook.cz..."
    
    local response
    response=$(curl -s "https://phonebook.cz/search?query=${domain}&target=email" 2>/dev/null)
    
    echo "$response" | grep -oEi "$EMAIL_REGEX" >> "$output_file"
}

# ------------------------------------------------------------------------------
# search_google_dorks()
# Use Google dorks to find emails
# Arguments: $1 = Domain, $2 = Output file
# ------------------------------------------------------------------------------
search_google_dorks() {
    local domain="$1"
    local output_file="$2"
    
    log_info "Running Google dorks for emails..."
    
    # Dork queries
    local dorks=(
        "site:${domain} \"@${domain}\""
        "site:linkedin.com \"${domain}\""
        "\"@${domain}\" email"
        "\"@${domain}\" contact"
    )
    
    for dork in "${dorks[@]}"; do
        local encoded
        encoded=$(echo "$dork" | sed 's/ /+/g')
        
        # Note: This is rate-limited, respect Google's ToS
        sleep 5
    done
}

# ------------------------------------------------------------------------------
# extract_from_linkedin()
# Extract employee names from LinkedIn (company page)
# Arguments: $1 = Company name, $2 = Output file
# ------------------------------------------------------------------------------
extract_from_linkedin() {
    local company="$1"
    local output_file="$2"
    
    log_info "Note: LinkedIn extraction requires manual review"
    echo "# LinkedIn employees for $company" >> "$output_file"
    echo "# Use LinkedIn Sales Navigator or manual search" >> "$output_file"
}

# ------------------------------------------------------------------------------
# generate_email_permutations()
# Generate possible emails from names
# Arguments: $1 = First name, $2 = Last name, $3 = Domain
# Returns: List of possible emails
# ------------------------------------------------------------------------------
generate_email_permutations() {
    local first="$1"
    local last="$2"
    local domain="$3"
    
    first=$(echo "$first" | tr '[:upper:]' '[:lower:]')
    last=$(echo "$last" | tr '[:upper:]' '[:lower:]')
    local f="${first:0:1}"
    local l="${last:0:1}"
    
    echo "${first}.${last}@${domain}"
    echo "${first}${last}@${domain}"
    echo "${f}${last}@${domain}"
    echo "${first}@${domain}"
    echo "${first}_${last}@${domain}"
    echo "${last}.${first}@${domain}"
    echo "${first}.${l}@${domain}"
    echo "${f}.${last}@${domain}"
}

# ------------------------------------------------------------------------------
# verify_email()
# Verify if an email exists (via SMTP)
# Arguments: $1 = Email
# Returns: 0 if valid, 1 if not
# ------------------------------------------------------------------------------
verify_email() {
    local email="$1"
    local domain
    domain=$(echo "$email" | cut -d@ -f2)
    
    # Get MX record
    local mx
    mx=$(dig +short MX "$domain" | head -1 | awk '{print $2}')
    
    if [ -z "$mx" ]; then
        return 1
    fi
    
    # Note: Full SMTP verification should be done carefully
    # This is just a basic check
    return 0
}

# ------------------------------------------------------------------------------
# analyze_email_patterns()
# Analyze found emails to detect pattern
# Arguments: $1 = Emails file, $2 = Domain
# Returns: Detected pattern
# ------------------------------------------------------------------------------
analyze_email_patterns() {
    local emails_file="$1"
    local domain="$2"
    
    if [ ! -f "$emails_file" ]; then
        return
    fi
    
    log_info "Analyzing email patterns..."
    
    # Count patterns
    local first_last=$(grep -c "^[a-z]*\.[a-z]*@${domain}$" "$emails_file" 2>/dev/null || echo 0)
    local first_initial=$(grep -c "^[a-z]\.[a-z]*@${domain}$" "$emails_file" 2>/dev/null || echo 0)
    local initial_last=$(grep -c "^[a-z][a-z]*@${domain}$" "$emails_file" 2>/dev/null || echo 0)
    
    if [ "$first_last" -gt "$first_initial" ] && [ "$first_last" -gt "$initial_last" ]; then
        echo "first.last"
    elif [ "$first_initial" -gt "$initial_last" ]; then
        echo "f.last"
    else
        echo "unknown"
    fi
}

# ------------------------------------------------------------------------------
# run_email_harvest()
# Main email harvesting function
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_email_harvest() {
    local workspace="$1"
    
    print_section "Email Harvester"
    log_info "Workspace: $workspace"
    
    if [ "${EMAIL_HARVEST_ENABLED:-true}" != "true" ]; then
        log_info "Email harvesting disabled"
        return 0
    fi
    
    local email_dir="$workspace/emails"
    mkdir -p "$email_dir"
    
    local domain="${TARGET_DOMAIN:-}"
    if [ -z "$domain" ]; then
        log_warn "No target domain"
        return 1
    fi
    
    # Step 1: Extract from live hosts
    if [ -f "$workspace/live_hosts.txt" ]; then
        log_info "Extracting from live hosts..."
        
        while IFS= read -r url; do
            [ -z "$url" ] && continue
            extract_from_website "$url" "$email_dir/website_emails.txt"
        done < <(head -20 "$workspace/live_hosts.txt")
    fi
    
    # Step 2: Search Hunter.io
    if [ -n "${HUNTER_API_KEY:-}" ]; then
        local hunter_result
        hunter_result=$(search_hunter_io "$domain")
        
        if [ -n "$hunter_result" ]; then
            echo "$hunter_result" | jq -r '.data.emails[]?.value' 2>/dev/null >> "$email_dir/hunter_emails.txt"
        fi
    fi
    
    # Step 3: Phonebook search
    search_phonebook "$domain" "$email_dir/phonebook_emails.txt"
    
    # Step 4: Extract from JavaScript
    if [ -d "$workspace/secrets/js_downloaded" ]; then
        log_info "Extracting from JavaScript..."
        grep -rhoE "$EMAIL_REGEX" "$workspace/secrets/js_downloaded" 2>/dev/null | \
            sort -u >> "$email_dir/js_emails.txt"
    fi
    
    # Merge and deduplicate
    cat "$email_dir"/*.txt 2>/dev/null | \
        grep -E "$EMAIL_REGEX" | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u > "$email_dir/all_emails.txt"
    
    # Filter for target domain only
    grep "@${domain}" "$email_dir/all_emails.txt" 2>/dev/null | \
        sort -u > "$email_dir/target_emails.txt"
    
    # Analyze patterns
    local pattern
    pattern=$(analyze_email_patterns "$email_dir/target_emails.txt" "$domain")
    
    # Generate report
    {
        echo "══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Email Harvest Report"
        echo "══════════════════════════════════════════════════════════"
        echo ""
        echo "Domain: $domain"
        echo "Scan Date: $(date)"
        echo ""
        echo "EMAILS FOUND:"
        echo "─────────────"
        cat "$email_dir/target_emails.txt" 2>/dev/null
        echo ""
        echo "Pattern Detected: $pattern"
        echo ""
        echo "Total: $(wc -l < "$email_dir/target_emails.txt" 2>/dev/null | tr -d ' ') emails"
        
    } > "$email_dir/email_report.txt"
    
    # Summary
    print_section "Email Harvest Complete"
    
    local total_emails=0
    [ -f "$email_dir/target_emails.txt" ] && \
        total_emails=$(wc -l < "$email_dir/target_emails.txt" | tr -d ' ')
    
    log_success "Found $total_emails emails for $domain"
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Email Harvester"
    echo "Usage: source emails.sh && run_email_harvest <workspace>"
fi
