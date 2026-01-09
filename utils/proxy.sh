#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Proxy Support Module
# ==============================================================================
# File: utils/proxy.sh
# Description: Proxy configuration for Burp Suite, ZAP, and custom proxies
# License: MIT
# Version: 1.2.0
# ==============================================================================

# Default proxy settings
PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${PROXY_PORT:-8080}"
PROXY_ENABLED="${PROXY_ENABLED:-false}"

# Burp Suite defaults
BURP_HOST="${BURP_HOST:-127.0.0.1}"
BURP_PORT="${BURP_PORT:-8080}"

# ZAP defaults
ZAP_HOST="${ZAP_HOST:-127.0.0.1}"
ZAP_PORT="${ZAP_PORT:-8090}"
ZAP_API_KEY="${ZAP_API_KEY:-}"

# ------------------------------------------------------------------------------
# check_proxy_running()
# Check if proxy is accepting connections
# Arguments: $1 = Host, $2 = Port
# Returns: 0 if running, 1 if not
# ------------------------------------------------------------------------------
check_proxy_running() {
    local host="${1:-$PROXY_HOST}"
    local port="${2:-$PROXY_PORT}"
    
    if command -v nc &>/dev/null; then
        nc -z -w2 "$host" "$port" 2>/dev/null
        return $?
    fi
    
    # Fallback to curl
    curl -s --max-time 2 --proxy "http://${host}:${port}" http://example.com &>/dev/null
    return $?
}

# ------------------------------------------------------------------------------
# enable_proxy()
# Enable proxy for all requests
# Arguments: $1 = Host (optional), $2 = Port (optional)
# ------------------------------------------------------------------------------
enable_proxy() {
    local host="${1:-$PROXY_HOST}"
    local port="${2:-$PROXY_PORT}"
    
    if ! check_proxy_running "$host" "$port"; then
        log_warn "Proxy not responding at $host:$port"
        return 1
    fi
    
    export PROXY_ENABLED="true"
    export PROXY_HOST="$host"
    export PROXY_PORT="$port"
    export http_proxy="http://${host}:${port}"
    export https_proxy="http://${host}:${port}"
    export HTTP_PROXY="http://${host}:${port}"
    export HTTPS_PROXY="http://${host}:${port}"
    
    log_info "Proxy enabled: $host:$port"
    return 0
}

# ------------------------------------------------------------------------------
# disable_proxy()
# Disable proxy for all requests
# ------------------------------------------------------------------------------
disable_proxy() {
    export PROXY_ENABLED="false"
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    
    log_info "Proxy disabled"
}

# ------------------------------------------------------------------------------
# get_curl_proxy_opts()
# Get curl options for proxy
# Returns: Curl proxy options string
# ------------------------------------------------------------------------------
get_curl_proxy_opts() {
    if [ "${PROXY_ENABLED:-false}" = "true" ]; then
        echo "--proxy http://${PROXY_HOST}:${PROXY_PORT} --proxy-insecure"
    fi
}

# ------------------------------------------------------------------------------
# get_nuclei_proxy_opts()
# Get Nuclei options for proxy
# Returns: Nuclei proxy options string
# ------------------------------------------------------------------------------
get_nuclei_proxy_opts() {
    if [ "${PROXY_ENABLED:-false}" = "true" ]; then
        echo "-proxy http://${PROXY_HOST}:${PROXY_PORT}"
    fi
}

# ------------------------------------------------------------------------------
# get_httpx_proxy_opts()
# Get httpx options for proxy
# Returns: httpx proxy options string
# ------------------------------------------------------------------------------
get_httpx_proxy_opts() {
    if [ "${PROXY_ENABLED:-false}" = "true" ]; then
        echo "-http-proxy http://${PROXY_HOST}:${PROXY_PORT}"
    fi
}

# ------------------------------------------------------------------------------
# connect_burp()
# Configure proxy for Burp Suite
# Arguments: $1 = Host (optional), $2 = Port (optional)
# ------------------------------------------------------------------------------
connect_burp() {
    local host="${1:-$BURP_HOST}"
    local port="${2:-$BURP_PORT}"
    
    log_info "Connecting to Burp Suite at $host:$port..."
    
    if enable_proxy "$host" "$port"; then
        export PROXY_TYPE="burp"
        log_success "Connected to Burp Suite"
        return 0
    else
        log_error "Could not connect to Burp Suite"
        log_info "Make sure Burp is running and proxy listener is on port $port"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# connect_zap()
# Configure proxy for OWASP ZAP
# Arguments: $1 = Host (optional), $2 = Port (optional)
# ------------------------------------------------------------------------------
connect_zap() {
    local host="${1:-$ZAP_HOST}"
    local port="${2:-$ZAP_PORT}"
    
    log_info "Connecting to OWASP ZAP at $host:$port..."
    
    if enable_proxy "$host" "$port"; then
        export PROXY_TYPE="zap"
        log_success "Connected to OWASP ZAP"
        return 0
    else
        log_error "Could not connect to OWASP ZAP"
        log_info "Make sure ZAP is running and listening on port $port"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# zap_spider()
# Run ZAP spider via API
# Arguments: $1 = URL
# ------------------------------------------------------------------------------
zap_spider() {
    local url="$1"
    
    if [ -z "$ZAP_API_KEY" ]; then
        log_warn "ZAP_API_KEY not set"
        return 1
    fi
    
    log_info "Starting ZAP spider on $url..."
    
    local response
    response=$(curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/spider/action/scan/?apikey=${ZAP_API_KEY}&url=${url}" 2>/dev/null)
    
    echo "$response"
}

# ------------------------------------------------------------------------------
# zap_active_scan()
# Run ZAP active scan via API
# Arguments: $1 = URL
# ------------------------------------------------------------------------------
zap_active_scan() {
    local url="$1"
    
    if [ -z "$ZAP_API_KEY" ]; then
        log_warn "ZAP_API_KEY not set"
        return 1
    fi
    
    log_info "Starting ZAP active scan on $url..."
    
    local response
    response=$(curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/ascan/action/scan/?apikey=${ZAP_API_KEY}&url=${url}" 2>/dev/null)
    
    echo "$response"
}

# ------------------------------------------------------------------------------
# zap_get_alerts()
# Get ZAP alerts via API
# Returns: JSON alerts
# ------------------------------------------------------------------------------
zap_get_alerts() {
    if [ -z "$ZAP_API_KEY" ]; then
        return 1
    fi
    
    curl -s "http://${ZAP_HOST}:${ZAP_PORT}/JSON/core/view/alerts/?apikey=${ZAP_API_KEY}" 2>/dev/null
}

# ------------------------------------------------------------------------------
# proxy_curl()
# Execute curl with proxy if enabled
# Arguments: All curl arguments
# ------------------------------------------------------------------------------
proxy_curl() {
    local proxy_opts
    proxy_opts=$(get_curl_proxy_opts)
    
    curl $proxy_opts "$@"
}

# ------------------------------------------------------------------------------
# show_proxy_status()
# Display current proxy configuration
# ------------------------------------------------------------------------------
show_proxy_status() {
    echo ""
    print_section "Proxy Configuration"
    
    if [ "${PROXY_ENABLED:-false}" = "true" ]; then
        echo -e "Status:     \033[0;32mENABLED\033[0m"
        echo "Type:       ${PROXY_TYPE:-custom}"
        echo "Host:       $PROXY_HOST"
        echo "Port:       $PROXY_PORT"
        echo "http_proxy: ${http_proxy:-not set}"
    else
        echo -e "Status:     \033[0;33mDISABLED\033[0m"
    fi
    
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Proxy Support"
    echo ""
    echo "Usage:"
    echo "  source proxy.sh"
    echo "  connect_burp [host] [port]  - Connect to Burp Suite"
    echo "  connect_zap [host] [port]   - Connect to OWASP ZAP"
    echo "  enable_proxy [host] [port]  - Enable custom proxy"
    echo "  disable_proxy               - Disable proxy"
    echo "  show_proxy_status           - Show current config"
fi
