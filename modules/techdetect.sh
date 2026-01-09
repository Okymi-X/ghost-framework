#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Technology Fingerprinting Module
# ==============================================================================
# File: modules/techdetect.sh
# Description: Advanced technology detection and version identification
# License: MIT
# Version: 1.2.0
# ==============================================================================

# Technology signatures (header patterns)
declare -A TECH_HEADERS=(
    ["X-Powered-By: PHP"]="PHP"
    ["X-Powered-By: ASP.NET"]="ASP.NET"
    ["X-Powered-By: Express"]="Express.js"
    ["X-Powered-By: Next.js"]="Next.js"
    ["Server: nginx"]="Nginx"
    ["Server: Apache"]="Apache"
    ["Server: Microsoft-IIS"]="IIS"
    ["Server: cloudflare"]="Cloudflare"
    ["Server: AmazonS3"]="Amazon S3"
    ["Server: gws"]="Google Web Server"
    ["Server: openresty"]="OpenResty"
    ["X-Generator: Drupal"]="Drupal"
    ["X-Drupal-Cache"]="Drupal"
    ["X-Shopify-Stage"]="Shopify"
    ["X-Wix-"]="Wix"
    ["X-WordPress"]="WordPress"
    ["Via: .* varnish"]="Varnish"
    ["X-Varnish"]="Varnish"
)

# Technology signatures (body patterns)
declare -A TECH_BODY=(
    ["wp-content"]="WordPress"
    ["wp-includes"]="WordPress"
    ["/wp-json/"]="WordPress REST API"
    ["Joomla!"]="Joomla"
    ["/administrator/"]="Joomla"
    ["Drupal.settings"]="Drupal"
    ["sites/default/files"]="Drupal"
    ["Laravel"]="Laravel"
    ["laravel_session"]="Laravel"
    ["csrf-token"]="Laravel/Rails"
    ["__VIEWSTATE"]="ASP.NET"
    ["__EVENTVALIDATION"]="ASP.NET"
    ["react-root"]="React"
    ["__NEXT_DATA__"]="Next.js"
    ["ng-version"]="Angular"
    ["ng-app"]="AngularJS"
    ["ember-cli"]="Ember.js"
    ["vue-"]="Vue.js"
    ["nuxt"]="Nuxt.js"
    ["svelte-"]="Svelte"
    ["shopify.com"]="Shopify"
    ["Shopify.theme"]="Shopify"
    ["magento"]="Magento"
    ["prestashop"]="PrestaShop"
    ["woocommerce"]="WooCommerce"
    ["jquery"]="jQuery"
    ["bootstrap"]="Bootstrap"
    ["tailwind"]="TailwindCSS"
    ["bulma"]="Bulma"
    ["foundation-"]="Foundation"
    ["graphql"]="GraphQL"
    ["swagger"]="Swagger/OpenAPI"
    ["api/v"]="REST API"
    ["firebase"]="Firebase"
    ["aws-sdk"]="AWS SDK"
    ["google-analytics"]="Google Analytics"
    ["gtag"]="Google Tag Manager"
    ["fbq"]="Facebook Pixel"
    ["recaptcha"]="reCAPTCHA"
    ["cloudflare"]="Cloudflare"
    ["akamai"]="Akamai"
    ["cdn."]="CDN"
)

# JavaScript framework detection patterns (exported for external use)
export JS_FRAMEWORKS="React Angular Vue Ember Backbone Svelte"

# ------------------------------------------------------------------------------
# detect_technologies_from_headers()
# Analyze response headers for technology signatures
# Arguments: $1 = Headers, $2 = Output array name
# ------------------------------------------------------------------------------
detect_from_headers() {
    local headers="$1"
    local output_var="$2"
    
    for pattern in "${!TECH_HEADERS[@]}"; do
        if echo "$headers" | grep -qi "$pattern"; then
            local tech="${TECH_HEADERS[$pattern]}"
            eval "${output_var}[\"$tech\"]=1"
        fi
    done
}

# ------------------------------------------------------------------------------
# detect_technologies_from_body()
# Analyze response body for technology signatures
# Arguments: $1 = Body content, $2 = Output array name
# ------------------------------------------------------------------------------
detect_from_body() {
    local body="$1"
    local output_var="$2"
    
    for pattern in "${!TECH_BODY[@]}"; do
        if echo "$body" | grep -qi "$pattern"; then
            local tech="${TECH_BODY[$pattern]}"
            eval "${output_var}[\"$tech\"]=1"
        fi
    done
}

# ------------------------------------------------------------------------------
# detect_cms()
# Identify CMS from common paths
# Arguments: $1 = URL
# Returns: CMS name or empty
# ------------------------------------------------------------------------------
detect_cms() {
    local url="$1"
    
    # WordPress
    if curl -s --max-time 5 "$url/wp-login.php" 2>/dev/null | grep -qi "wordpress"; then
        echo "WordPress"
        return
    fi
    
    # Joomla
    if curl -s --max-time 5 "$url/administrator/" 2>/dev/null | grep -qi "joomla"; then
        echo "Joomla"
        return
    fi
    
    # Drupal
    if curl -s --max-time 5 "$url/core/misc/drupal.js" 2>/dev/null | grep -qi "drupal"; then
        echo "Drupal"
        return
    fi
    
    # Magento
    if curl -s --max-time 5 "$url/skin/frontend/" 2>/dev/null | head -c 100 | grep -qi "magento\|varien"; then
        echo "Magento"
        return
    fi
}

# ------------------------------------------------------------------------------
# detect_waf_detailed()
# Detailed WAF detection
# Arguments: $1 = URL, $2 = Output file
# ------------------------------------------------------------------------------
detect_waf_detailed() {
    local url="$1"
    local output_file="$2"
    
    log_info "Performing detailed WAF detection..."
    
    # Get headers
    local headers
    headers=$(curl -s -I --max-time 10 "$url" 2>/dev/null)
    
    # WAF signatures
    declare -A waf_signatures=(
        ["cf-ray"]="Cloudflare"
        ["__cfduid"]="Cloudflare"
        ["x-sucuri-id"]="Sucuri"
        ["x-sucuri-cache"]="Sucuri"
        ["x-akamai"]="Akamai"
        ["akamai"]="Akamai"
        ["x-cdn: Incapsula"]="Incapsula"
        ["x-iinfo"]="Incapsula"
        ["x-distil-cs"]="Distil Networks"
        ["x-amz-cf-id"]="AWS CloudFront"
        ["x-amz-request-id"]="AWS WAF"
        ["x-ms-request-id"]="Azure"
        ["x-azure-ref"]="Azure CDN"
        ["server: BigIP"]="F5 BIG-IP"
        ["x-cnection"]="Citrix NetScaler"
        ["x-arbor-"]="Arbor Networks"
        ["x-fortiweb"]="FortiWeb"
        ["x-barracuda"]="Barracuda"
    )
    
    local detected_waf=""
    
    for sig in "${!waf_signatures[@]}"; do
        if echo "$headers" | grep -qi "$sig"; then
            detected_waf="${waf_signatures[$sig]}"
            break
        fi
    done
    
    if [ -n "$detected_waf" ]; then
        echo "[WAF] $url -> $detected_waf" >> "$output_file"
        echo "$detected_waf"
    fi
}

# ------------------------------------------------------------------------------
# scan_single_host()
# Perform technology detection on a single host
# Arguments: $1 = URL, $2 = Output directory
# ------------------------------------------------------------------------------
scan_single_host() {
    local url="$1"
    local output_dir="$2"
    
    # Fetch page
    local response
    response=$(curl -s -i --max-time 15 "$url" 2>/dev/null)
    
    local headers
    headers=$(echo "$response" | sed -n '1,/^\r$/p')
    
    local body
    body=$(echo "$response" | sed -n '/^\r$/,$p' | head -c 50000)
    
    # Detect technologies
    declare -A detected_tech
    
    detect_from_headers "$headers" detected_tech
    detect_from_body "$body" detected_tech
    
    # Check for CMS
    local cms
    cms=$(detect_cms "$url")
    [ -n "$cms" ] && detected_tech["$cms"]=1
    
    # Output results
    if [ ${#detected_tech[@]} -gt 0 ]; then
        echo "URL: $url" >> "$output_dir/technologies.txt"
        for tech in "${!detected_tech[@]}"; do
            echo "  - $tech" >> "$output_dir/technologies.txt"
        done
        echo "" >> "$output_dir/technologies.txt"
    fi
}

# ------------------------------------------------------------------------------
# generate_tech_report()
# Generate technology summary report
# Arguments: $1 = Tech directory
# ------------------------------------------------------------------------------
generate_tech_report() {
    local tech_dir="$1"
    local report_file="$tech_dir/tech_summary.txt"
    
    {
        echo "══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Technology Report"
        echo "══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date)"
        echo ""
        
        if [ -f "$tech_dir/technologies.txt" ]; then
            echo "DETECTED TECHNOLOGIES:"
            echo "──────────────────────"
            grep "^  -" "$tech_dir/technologies.txt" | sort | uniq -c | sort -rn | head -20
            echo ""
            
            echo "TECHNOLOGY DISTRIBUTION:"
            echo "────────────────────────"
            echo "CMS/Frameworks:"
            grep -iE "wordpress|joomla|drupal|magento|shopify" "$tech_dir/technologies.txt" 2>/dev/null | wc -l | xargs echo "  "
            echo ""
        fi
        
        if [ -f "$tech_dir/waf_detection.txt" ]; then
            echo "WAF/CDN DETECTION:"
            echo "──────────────────"
            cat "$tech_dir/waf_detection.txt"
        fi
        
    } > "$report_file"
}

# ------------------------------------------------------------------------------
# run_tech_detection()
# Main technology detection function
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_tech_detection() {
    local workspace="$1"
    
    print_section "Technology Detection"
    log_info "Workspace: $workspace"
    
    if [ "${TECH_DETECTION_ENABLED:-true}" != "true" ]; then
        log_info "Technology detection disabled"
        return 0
    fi
    
    local tech_dir="$workspace/technologies"
    mkdir -p "$tech_dir"
    
    # Get targets
    local targets_file="$workspace/live_hosts.txt"
    if [ ! -f "$targets_file" ]; then
        log_warn "No live hosts found"
        return 1
    fi
    
    local count=0
    local total
    total=$(wc -l < "$targets_file" | tr -d ' ')
    
    log_info "Scanning $total hosts for technologies..."
    
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        count=$((count + 1))
        
        log_debug "[$count/$total] $url"
        
        # Scan host
        scan_single_host "$url" "$tech_dir"
        
        # WAF detection
        detect_waf_detailed "$url" "$tech_dir/waf_detection.txt"
        
        [ "${IS_WAF:-false}" = "true" ] && sleep 1 || sleep 0.3
        
    done < <(head -50 "$targets_file")  # Limit for performance
    
    # Generate report
    generate_tech_report "$tech_dir"
    
    # Summary
    print_section "Tech Detection Complete"
    
    local tech_count=0
    [ -f "$tech_dir/technologies.txt" ] && \
        tech_count=$(grep -c "^  -" "$tech_dir/technologies.txt" 2>/dev/null || echo 0)
    
    log_info "Detected $tech_count technology instances"
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Technology Detection Module"
    echo "Usage: source techdetect.sh && run_tech_detection <workspace>"
fi
