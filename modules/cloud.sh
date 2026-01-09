#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Cloud Bucket Scanner Module
# ==============================================================================
# File: modules/cloud.sh
# Description: Detect exposed cloud storage buckets (S3, Azure, GCP)
# License: MIT
# Version: 1.2.0
# ==============================================================================

# Cloud provider patterns
declare -A BUCKET_PATTERNS=(
    ["s3"]="s3.amazonaws.com|s3-[a-z0-9-]+.amazonaws.com|[a-z0-9.-]+.s3.amazonaws.com|[a-z0-9.-]+.s3-[a-z0-9-]+.amazonaws.com"
    ["azure"]="blob.core.windows.net|[a-z0-9]+.blob.core.windows.net"
    ["gcp"]="storage.googleapis.com|[a-z0-9.-]+.storage.googleapis.com|storage.cloud.google.com"
    ["digitalocean"]="[a-z0-9.-]+.digitaloceanspaces.com"
    ["alibaba"]="[a-z0-9.-]+.oss-[a-z0-9-]+.aliyuncs.com"
)

# Bucket permission test payloads
readonly S3_TEST_PATHS=("" "?acl" "?policy" "?cors" "?lifecycle" "?location")

# ------------------------------------------------------------------------------
# extract_buckets_from_urls()
# Extract cloud bucket URLs from crawled URLs
# Arguments: $1 = URLs file, $2 = Output file
# ------------------------------------------------------------------------------
extract_buckets_from_urls() {
    local urls_file="$1"
    local output_file="$2"
    
    log_info "Extracting cloud bucket references..."
    
    if [ ! -f "$urls_file" ]; then
        return 1
    fi
    
    local found=0
    
    # Search for bucket patterns
    for provider in "${!BUCKET_PATTERNS[@]}"; do
        local pattern="${BUCKET_PATTERNS[$provider]}"
        local matches
        matches=$(grep -oEi "$pattern" "$urls_file" 2>/dev/null | sort -u)
        
        if [ -n "$matches" ]; then
            echo "# $provider buckets" >> "$output_file"
            echo "$matches" >> "$output_file"
            found=$((found + $(echo "$matches" | wc -l)))
        fi
    done
    
    log_info "Found $found cloud bucket references"
    return 0
}

# ------------------------------------------------------------------------------
# extract_buckets_from_js()
# Extract bucket references from JavaScript files
# Arguments: $1 = JS directory, $2 = Output file
# ------------------------------------------------------------------------------
extract_buckets_from_js() {
    local js_dir="$1"
    local output_file="$2"
    
    if [ ! -d "$js_dir" ]; then
        return 1
    fi
    
    log_info "Scanning JavaScript files for bucket references..."
    
    for provider in "${!BUCKET_PATTERNS[@]}"; do
        local pattern="${BUCKET_PATTERNS[$provider]}"
        grep -rhoEi "$pattern" "$js_dir" 2>/dev/null >> "$output_file"
    done
    
    # Also look for bucket names in config patterns
    grep -rhoEi "bucket['\"]?\s*[:=]\s*['\"][^'\"]+['\"]" "$js_dir" 2>/dev/null >> "$output_file"
    grep -rhoEi "AWS_BUCKET|S3_BUCKET|AZURE_CONTAINER|GCS_BUCKET" "$js_dir" 2>/dev/null >> "$output_file"
    
    sort -u "$output_file" -o "$output_file" 2>/dev/null
}

# ------------------------------------------------------------------------------
# check_s3_bucket_permissions()
# Check S3 bucket for misconfigurations
# Arguments: $1 = Bucket name, $2 = Output file
# Returns: 0 if vulnerable, 1 if not
# ------------------------------------------------------------------------------
check_s3_bucket_permissions() {
    local bucket="$1"
    local output_file="$2"
    
    local vulnerable=false
    local issues=""
    
    # Test listing
    local list_response
    list_response=$(curl -s --max-time 10 "https://${bucket}.s3.amazonaws.com/" 2>/dev/null)
    
    if echo "$list_response" | grep -q "<Contents>"; then
        vulnerable=true
        issues="$issues [LIST_ENABLED]"
        echo -e "\033[1;31m[CRITICAL]\033[0m S3 bucket listing enabled: $bucket"
        increment_finding "critical" 2>/dev/null || true
    fi
    
    # Test ACL access
    local acl_response
    acl_response=$(curl -s --max-time 10 "https://${bucket}.s3.amazonaws.com/?acl" 2>/dev/null)
    
    if echo "$acl_response" | grep -q "<AccessControlList>"; then
        vulnerable=true
        issues="$issues [ACL_READABLE]"
    fi
    
    # Test write access (safe - just checks response)
    local put_response
    put_response=$(curl -s -X PUT --max-time 10 -o /dev/null -w "%{http_code}" "https://${bucket}.s3.amazonaws.com/ghost-test-write-check.txt" 2>/dev/null)
    
    if [ "$put_response" = "200" ] || [ "$put_response" = "100" ]; then
        vulnerable=true
        issues="$issues [WRITE_ENABLED]"
        echo -e "\033[1;31m[CRITICAL]\033[0m S3 bucket WRITE enabled: $bucket"
        increment_finding "critical" 2>/dev/null || true
    fi
    
    if [ "$vulnerable" = true ]; then
        echo "[S3] $bucket $issues" >> "$output_file"
        return 0
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# check_azure_container()
# Check Azure blob container for misconfigurations
# Arguments: $1 = Container URL, $2 = Output file
# ------------------------------------------------------------------------------
check_azure_container() {
    local container_url="$1"
    local output_file="$2"
    
    # Test listing with restype=container&comp=list
    local response
    response=$(curl -s --max-time 10 "${container_url}?restype=container&comp=list" 2>/dev/null)
    
    if echo "$response" | grep -q "<Blob>"; then
        echo "[AZURE] Public listing: $container_url" >> "$output_file"
        echo -e "\033[1;31m[CRITICAL]\033[0m Azure container public: $container_url"
        increment_finding "critical" 2>/dev/null || true
        return 0
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# check_gcp_bucket()
# Check GCP bucket for misconfigurations
# Arguments: $1 = Bucket name, $2 = Output file
# ------------------------------------------------------------------------------
check_gcp_bucket() {
    local bucket="$1"
    local output_file="$2"
    
    local response
    response=$(curl -s --max-time 10 "https://storage.googleapis.com/${bucket}" 2>/dev/null)
    
    if echo "$response" | grep -q "<Contents>" || echo "$response" | grep -q "<Key>"; then
        echo "[GCP] Public bucket: $bucket" >> "$output_file"
        echo -e "\033[1;31m[CRITICAL]\033[0m GCP bucket public: $bucket"
        increment_finding "critical" 2>/dev/null || true
        return 0
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# bruteforce_bucket_names()
# Try common bucket naming patterns
# Arguments: $1 = Domain, $2 = Output file
# ------------------------------------------------------------------------------
bruteforce_bucket_names() {
    local domain="$1"
    local output_file="$2"
    
    log_info "Bruteforcing common bucket names..."
    
    # Extract domain parts
    local base_name
    base_name=$(echo "$domain" | sed 's/\.[^.]*$//' | tr '.' '-')
    
    # Common patterns
    local patterns=(
        "$base_name"
        "$base_name-backup"
        "$base_name-backups"
        "$base_name-assets"
        "$base_name-static"
        "$base_name-media"
        "$base_name-uploads"
        "$base_name-files"
        "$base_name-data"
        "$base_name-prod"
        "$base_name-production"
        "$base_name-dev"
        "$base_name-development"
        "$base_name-stage"
        "$base_name-staging"
        "$base_name-test"
        "$base_name-logs"
        "$base_name-www"
        "$base_name-web"
        "$base_name-public"
        "$base_name-private"
        "$base_name-internal"
        "$domain"
        "www-$base_name"
        "backup-$base_name"
    )
    
    local found=0
    
    for pattern in "${patterns[@]}"; do
        # Check S3
        local s3_check
        s3_check=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${pattern}.s3.amazonaws.com/" 2>/dev/null)
        
        if [ "$s3_check" != "404" ] && [ "$s3_check" != "000" ]; then
            echo "[S3-FOUND] $pattern (HTTP $s3_check)" >> "$output_file"
            
            if [ "$s3_check" = "200" ]; then
                check_s3_bucket_permissions "$pattern" "$output_file"
                found=$((found + 1))
            fi
        fi
        
        # Rate limiting
        [ "${IS_WAF:-false}" = "true" ] && sleep 1 || sleep 0.2
    done
    
    log_info "Found $found accessible buckets"
}

# ------------------------------------------------------------------------------
# run_cloud_scan()
# Main function for cloud bucket scanning
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_cloud_scan() {
    local workspace="$1"
    
    print_section "Cloud Bucket Scanner"
    log_info "Workspace: $workspace"
    
    if [ "${CLOUD_SCAN_ENABLED:-true}" != "true" ]; then
        log_info "Cloud scanning disabled in config"
        return 0
    fi
    
    local cloud_dir="$workspace/cloud"
    mkdir -p "$cloud_dir"
    
    # Step 1: Extract bucket references from crawled URLs
    if [ -f "$workspace/all_urls.txt" ]; then
        extract_buckets_from_urls "$workspace/all_urls.txt" "$cloud_dir/bucket_refs.txt"
    fi
    
    # Step 2: Extract from JavaScript
    if [ -d "$workspace/secrets/js_downloaded" ]; then
        extract_buckets_from_js "$workspace/secrets/js_downloaded" "$cloud_dir/js_buckets.txt"
    fi
    
    # Step 3: Bruteforce common names
    if [ -n "${TARGET_DOMAIN:-}" ]; then
        bruteforce_bucket_names "$TARGET_DOMAIN" "$cloud_dir/bruteforce_results.txt"
    fi
    
    # Step 4: Check found buckets for misconfigurations
    log_info "Checking bucket permissions..."
    
    local all_buckets="$cloud_dir/all_buckets.txt"
    cat "$cloud_dir"/*.txt 2>/dev/null | grep -oEi "[a-z0-9.-]+" | sort -u > "$all_buckets"
    
    while IFS= read -r bucket; do
        [ -z "$bucket" ] || [ ${#bucket} -lt 3 ] && continue
        
        # Determine provider and check
        if echo "$bucket" | grep -qi "s3\|amazonaws"; then
            check_s3_bucket_permissions "$bucket" "$cloud_dir/vulnerable_buckets.txt"
        elif echo "$bucket" | grep -qi "azure\|blob.core"; then
            check_azure_container "https://$bucket" "$cloud_dir/vulnerable_buckets.txt"
        elif echo "$bucket" | grep -qi "storage.googleapis\|storage.cloud.google"; then
            check_gcp_bucket "$bucket" "$cloud_dir/vulnerable_buckets.txt"
        fi
        
    done < "$all_buckets"
    
    # Summary
    print_section "Cloud Scan Complete"
    
    local vuln_count=0
    [ -f "$cloud_dir/vulnerable_buckets.txt" ] && \
        vuln_count=$(wc -l < "$cloud_dir/vulnerable_buckets.txt" | tr -d ' ')
    
    if [ "$vuln_count" -gt 0 ]; then
        log_critical "Found $vuln_count vulnerable cloud buckets!"
        notify_finding "CRITICAL" "Exposed Cloud Buckets" "$vuln_count buckets" "Cloud scan" 2>/dev/null &
    else
        log_info "No vulnerable buckets found"
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Cloud Bucket Scanner"
    echo "Usage: source cloud.sh && run_cloud_scan <workspace>"
fi
