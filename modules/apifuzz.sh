#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - API Fuzzer Module
# ==============================================================================
# File: modules/apifuzz.sh
# Description: Fuzzing REST/GraphQL APIs for security issues
# License: MIT
# Version: 1.3.0
# ==============================================================================

# API endpoint patterns to detect
readonly API_PATTERNS='(/api/|/v[0-9]/|/rest/|/graphql|/query|/service/)'

# Common API paths to fuzz
declare -a API_PATHS=(
    "api"
    "api/v1"
    "api/v2"
    "api/v3"
    "rest"
    "graphql"
    "query"
    "swagger"
    "swagger.json"
    "swagger/v1/swagger.json"
    "api-docs"
    "openapi.json"
    "openapi.yaml"
    "spec"
    "docs"
    "api/docs"
    "api/swagger"
    "api/health"
    "api/status"
    "api/version"
    "api/info"
    "api/debug"
    "api/config"
    "api/admin"
    "api/users"
    "api/user"
    "api/auth"
    "api/login"
    "api/register"
    "api/token"
    "api/refresh"
    "api/search"
    "api/data"
    "api/export"
    "api/import"
    "api/upload"
    "api/download"
    "api/files"
    "api/internal"
    "api/private"
    "api/public"
)

# HTTP methods to test (exported for external use)
export API_METHODS="GET POST PUT DELETE PATCH OPTIONS"

# Dangerous parameters for IDOR testing (exported for external use)
export IDOR_PARAMS="id user_id userId uid account account_id file doc page folder order invoice"

# ------------------------------------------------------------------------------
# detect_api_endpoints()
# Find API endpoints from crawled URLs
# Arguments: $1 = URLs file, $2 = Output file
# ------------------------------------------------------------------------------
detect_api_endpoints() {
    local urls_file="$1"
    local output_file="$2"
    
    if [ ! -f "$urls_file" ]; then
        return 1
    fi
    
    log_info "Detecting API endpoints..."
    
    grep -E "$API_PATTERNS" "$urls_file" 2>/dev/null | sort -u > "$output_file"
    
    local count
    count=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
    log_info "Found $count API endpoints"
}

# ------------------------------------------------------------------------------
# discover_api_paths()
# Brute force common API paths
# Arguments: $1 = Base URL, $2 = Output file
# ------------------------------------------------------------------------------
discover_api_paths() {
    local base_url="$1"
    local output_file="$2"
    
    log_info "Discovering API paths on $base_url..."
    
    local found=0
    
    for path in "${API_PATHS[@]}"; do
        local url="${base_url}/${path}"
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
        
        case "$response" in
            200|201|301|302|401|403)
                echo "[$response] $url" >> "$output_file"
                found=$((found + 1))
                log_debug "Found: $url ($response)"
                ;;
        esac
        
        [ "${IS_WAF:-false}" = "true" ] && sleep 0.5 || sleep 0.1
    done
    
    return 0
}

# ------------------------------------------------------------------------------
# check_swagger_docs()
# Check for exposed Swagger/OpenAPI documentation
# Arguments: $1 = Base URL, $2 = Output directory
# ------------------------------------------------------------------------------
check_swagger_docs() {
    local base_url="$1"
    local output_dir="$2"
    
    log_info "Checking for API documentation..."
    
    local swagger_paths=(
        "/swagger.json"
        "/swagger/v1/swagger.json"
        "/api-docs"
        "/v2/api-docs"
        "/v3/api-docs"
        "/openapi.json"
        "/openapi.yaml"
        "/api/swagger.json"
        "/swagger-ui.html"
        "/swagger-resources"
        "/api/spec"
    )
    
    for path in "${swagger_paths[@]}"; do
        local url="${base_url}${path}"
        local response
        response=$(curl -s --max-time 10 "$url" 2>/dev/null)
        
        if echo "$response" | grep -qE '(swagger|openapi|paths|definitions)'; then
            log_warn "API documentation exposed: $url"
            echo "$response" > "$output_dir/swagger_$(echo "$path" | tr '/' '_').json"
            echo "[SWAGGER] $url" >> "$output_dir/api_docs.txt"
            increment_finding "info" 2>/dev/null || true
        fi
    done
}

# ------------------------------------------------------------------------------
# test_method_override()
# Test for HTTP method override vulnerabilities
# Arguments: $1 = URL, $2 = Output file
# ------------------------------------------------------------------------------
test_method_override() {
    local url="$1"
    local output_file="$2"
    
    # Override headers to test
    local override_headers=(
        "X-HTTP-Method-Override: DELETE"
        "X-HTTP-Method: DELETE"
        "X-Method-Override: DELETE"
    )
    
    for header in "${override_headers[@]}"; do
        local response
        response=$(curl -s -X POST -H "$header" -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
        
        if [ "$response" != "405" ] && [ "$response" != "403" ]; then
            echo "[METHOD-OVERRIDE] $url - $header ($response)" >> "$output_file"
        fi
    done
}

# ------------------------------------------------------------------------------
# test_idor()
# Test for Insecure Direct Object Reference
# Arguments: $1 = URL with ID, $2 = Output file
# ------------------------------------------------------------------------------
test_idor() {
    local url="$1"
    local output_file="$2"
    
    # Extract numeric IDs and try adjacent values
    local ids
    ids=$(echo "$url" | grep -oE '[0-9]+')
    
    for id in $ids; do
        # Try id-1 and id+1
        local prev=$((id - 1))
        local next=$((id + 1))
        
        local test_url_prev
        test_url_prev=$(echo "$url" | sed "s/$id/$prev/")
        local test_url_next
        test_url_next=$(echo "$url" | sed "s/$id/$next/")
        
        local resp_prev resp_next
        resp_prev=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$test_url_prev" 2>/dev/null)
        resp_next=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$test_url_next" 2>/dev/null)
        
        # If we can access other IDs, potential IDOR
        if [ "$resp_prev" = "200" ] || [ "$resp_next" = "200" ]; then
            echo "[IDOR-POTENTIAL] $url -> IDs $prev/$next also accessible" >> "$output_file"
            log_warn "Potential IDOR: $url"
        fi
        
        break  # Only test first ID found
    done
}

# ------------------------------------------------------------------------------
# test_mass_assignment()
# Test for mass assignment vulnerabilities
# Arguments: $1 = URL, $2 = Output file
# ------------------------------------------------------------------------------
test_mass_assignment() {
    local url="$1"
    local output_file="$2"
    
    # Dangerous fields
    local dangerous_fields='{"admin":true,"role":"admin","isAdmin":true,"is_admin":1,"verified":true,"email_verified":true}'
    
    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$dangerous_fields" --max-time 10 "$url" 2>/dev/null)
    
    # Check if any dangerous fields were accepted
    if echo "$response" | grep -qiE '(admin.*true|role.*admin|isAdmin.*true)'; then
        echo "[MASS-ASSIGNMENT] $url - Dangerous fields may be accepted" >> "$output_file"
        log_critical "Potential mass assignment: $url"
        increment_finding "high" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# test_graphql()
# Test GraphQL endpoints for common issues
# Arguments: $1 = URL, $2 = Output file
# ------------------------------------------------------------------------------
test_graphql() {
    local url="$1"
    local output_file="$2"
    
    log_info "Testing GraphQL endpoint: $url"
    
    # Introspection query
    local introspection='{"query":"query{__schema{types{name,fields{name}}}}"}'
    
    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "$introspection" --max-time 15 "$url" 2>/dev/null)
    
    if echo "$response" | grep -q "__schema"; then
        echo "[GRAPHQL-INTROSPECTION] $url - Schema exposed" >> "$output_file"
        echo "$response" > "${output_file%.txt}_schema.json"
        log_warn "GraphQL introspection enabled: $url"
        increment_finding "medium" 2>/dev/null || true
    fi
    
    # Test for batching (DoS potential)
    local batch='[{"query":"query{__typename}"},{"query":"query{__typename}"},{"query":"query{__typename}"}]'
    local batch_response
    batch_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$batch" --max-time 10 "$url" 2>/dev/null)
    
    if echo "$batch_response" | grep -q "__typename"; then
        echo "[GRAPHQL-BATCHING] $url - Query batching enabled" >> "$output_file"
    fi
}

# ------------------------------------------------------------------------------
# run_api_fuzz()
# Main API fuzzing function
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_api_fuzz() {
    local workspace="$1"
    
    print_section "API Fuzzer"
    log_info "Workspace: $workspace"
    
    if [ "${API_FUZZ_ENABLED:-true}" != "true" ]; then
        log_info "API fuzzing disabled"
        return 0
    fi
    
    local api_dir="$workspace/api"
    mkdir -p "$api_dir"
    
    # Step 1: Detect API endpoints from crawled URLs
    if [ -f "$workspace/all_urls.txt" ]; then
        detect_api_endpoints "$workspace/all_urls.txt" "$api_dir/detected_apis.txt"
    fi
    
    # Step 2: Discover API paths on live hosts
    if [ -f "$workspace/live_hosts.txt" ]; then
        log_info "Discovering API paths..."
        
        while IFS= read -r host; do
            [ -z "$host" ] && continue
            discover_api_paths "$host" "$api_dir/discovered_apis.txt"
            check_swagger_docs "$host" "$api_dir"
        done < <(head -10 "$workspace/live_hosts.txt")
    fi
    
    # Merge all API endpoints
    cat "$api_dir/detected_apis.txt" "$api_dir/discovered_apis.txt" 2>/dev/null | \
        grep -oE 'https?://[^ ]+' | sort -u > "$api_dir/all_apis.txt"
    
    # Step 3: Test each API endpoint
    log_info "Testing API endpoints..."
    
    while IFS= read -r api_url; do
        [ -z "$api_url" ] && continue
        
        # Test for method override
        test_method_override "$api_url" "$api_dir/vulnerabilities.txt"
        
        # Test for IDOR if URL contains IDs
        if echo "$api_url" | grep -qE '[0-9]+'; then
            test_idor "$api_url" "$api_dir/vulnerabilities.txt"
        fi
        
        # Test GraphQL if detected
        if echo "$api_url" | grep -qi "graphql"; then
            test_graphql "$api_url" "$api_dir/graphql_findings.txt"
        fi
        
        [ "${IS_WAF:-false}" = "true" ] && sleep 1 || sleep 0.3
        
    done < <(head -50 "$api_dir/all_apis.txt")
    
    # Summary
    print_section "API Fuzz Complete"
    
    local api_count vuln_count
    api_count=$(wc -l < "$api_dir/all_apis.txt" 2>/dev/null | tr -d ' ' || echo 0)
    vuln_count=$(wc -l < "$api_dir/vulnerabilities.txt" 2>/dev/null | tr -d ' ' || echo 0)
    
    log_info "API endpoints found: $api_count"
    [ "$vuln_count" -gt 0 ] && log_warn "Potential issues: $vuln_count"
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK API Fuzzer"
    echo "Usage: source apifuzz.sh && run_api_fuzz <workspace>"
fi
