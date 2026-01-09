#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Rate Limiter Module
# ==============================================================================
# File: utils/ratelimit.sh
# Description: Smart rate limiting with adaptive throttling
# License: MIT
# Version: 1.3.0
# ==============================================================================

# Rate limit configuration
RATE_LIMIT_ENABLED="${RATE_LIMIT_ENABLED:-true}"
RATE_LIMIT_REQUESTS="${RATE_LIMIT_REQUESTS:-100}"
RATE_LIMIT_PERIOD="${RATE_LIMIT_PERIOD:-60}"

# Tracking
declare -A REQUEST_COUNTS
declare -A LAST_RESET_TIME
GLOBAL_REQUEST_COUNT=0
LAST_GLOBAL_RESET=$(date +%s)

# ------------------------------------------------------------------------------
# init_rate_limiter()
# Initialize rate limiter
# Arguments: $1 = Requests per minute (optional)
# ------------------------------------------------------------------------------
init_rate_limiter() {
    local rpm="${1:-$RATE_LIMIT_REQUESTS}"
    RATE_LIMIT_REQUESTS="$rpm"
    GLOBAL_REQUEST_COUNT=0
    LAST_GLOBAL_RESET=$(date +%s)
    log_debug "Rate limiter initialized: $rpm req/min"
}

# ------------------------------------------------------------------------------
# check_rate_limit()
# Check if request should be throttled
# Arguments: $1 = Target host (optional for per-host limits)
# Returns: 0 if OK, 1 if should wait
# ------------------------------------------------------------------------------
check_rate_limit() {
    local host="${1:-global}"
    local now=$(date +%s)
    
    if [ "$RATE_LIMIT_ENABLED" != "true" ]; then
        return 0
    fi
    
    # Check if period has elapsed, reset counter
    local elapsed=$((now - LAST_GLOBAL_RESET))
    if [ "$elapsed" -ge "$RATE_LIMIT_PERIOD" ]; then
        GLOBAL_REQUEST_COUNT=0
        LAST_GLOBAL_RESET=$now
    fi
    
    # Check if over limit
    if [ "$GLOBAL_REQUEST_COUNT" -ge "$RATE_LIMIT_REQUESTS" ]; then
        return 1
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# wait_for_rate_limit()
# Wait until rate limit allows request
# Arguments: $1 = Target host (optional)
# ------------------------------------------------------------------------------
wait_for_rate_limit() {
    local host="${1:-global}"
    
    while ! check_rate_limit "$host"; do
        local now=$(date +%s)
        local wait_time=$((RATE_LIMIT_PERIOD - (now - LAST_GLOBAL_RESET)))
        [ "$wait_time" -lt 1 ] && wait_time=1
        
        log_debug "Rate limit reached, waiting ${wait_time}s..."
        sleep "$wait_time"
    done
}

# ------------------------------------------------------------------------------
# increment_request_count()
# Increment request counter
# Arguments: $1 = Target host (optional)
# ------------------------------------------------------------------------------
increment_request_count() {
    local host="${1:-global}"
    GLOBAL_REQUEST_COUNT=$((GLOBAL_REQUEST_COUNT + 1))
}

# ------------------------------------------------------------------------------
# rate_limited_request()
# Make a rate-limited HTTP request
# Arguments: All curl arguments
# ------------------------------------------------------------------------------
rate_limited_request() {
    wait_for_rate_limit
    increment_request_count
    curl "$@"
}

# ------------------------------------------------------------------------------
# adaptive_delay()
# Calculate adaptive delay based on response
# Arguments: $1 = HTTP status code, $2 = Current delay
# Returns: New delay in seconds
# ------------------------------------------------------------------------------
adaptive_delay() {
    local status="$1"
    local current_delay="${2:-0}"
    
    case "$status" in
        429)  # Too Many Requests
            echo $((current_delay * 2 + 5))
            ;;
        503)  # Service Unavailable
            echo $((current_delay * 2 + 3))
            ;;
        403)  # Forbidden (possible WAF)
            echo $((current_delay + 2))
            ;;
        *)
            # Gradually reduce delay on success
            local new_delay=$((current_delay - 1))
            [ "$new_delay" -lt 0 ] && new_delay=0
            echo "$new_delay"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# get_rate_limit_status()
# Get current rate limiter status
# Returns: Status string
# ------------------------------------------------------------------------------
get_rate_limit_status() {
    local remaining=$((RATE_LIMIT_REQUESTS - GLOBAL_REQUEST_COUNT))
    local now=$(date +%s)
    local reset_in=$((RATE_LIMIT_PERIOD - (now - LAST_GLOBAL_RESET)))
    [ "$reset_in" -lt 0 ] && reset_in=0
    
    echo "Requests: $GLOBAL_REQUEST_COUNT/$RATE_LIMIT_REQUESTS | Reset in: ${reset_in}s | Remaining: $remaining"
}

# ------------------------------------------------------------------------------
# set_waf_mode()
# Activate WAF evasion rate limiting
# ------------------------------------------------------------------------------
set_waf_mode() {
    RATE_LIMIT_REQUESTS=10
    RATE_LIMIT_PERIOD=60
    log_warn "WAF mode activated: 10 req/min"
}

# ------------------------------------------------------------------------------
# set_aggressive_mode()
# Set aggressive rate limiting
# ------------------------------------------------------------------------------
set_aggressive_mode() {
    RATE_LIMIT_REQUESTS=200
    RATE_LIMIT_PERIOD=60
    log_info "Aggressive mode: 200 req/min"
}

# ------------------------------------------------------------------------------
# set_stealth_mode()
# Set stealth rate limiting
# ------------------------------------------------------------------------------
set_stealth_mode() {
    RATE_LIMIT_REQUESTS=30
    RATE_LIMIT_PERIOD=60
    log_info "Stealth mode: 30 req/min"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Rate Limiter"
    echo ""
    echo "Usage:"
    echo "  source ratelimit.sh"
    echo "  init_rate_limiter [requests_per_minute]"
    echo "  wait_for_rate_limit"
    echo "  rate_limited_request [curl args]"
fi
