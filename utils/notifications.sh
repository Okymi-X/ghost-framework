#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Notification Utilities
# ==============================================================================
# File: utils/notifications.sh
# Description: Discord, Slack, and Telegram webhook integrations
# License: MIT
# ==============================================================================

# ------------------------------------------------------------------------------
# Notification Configuration
# These should be set in config/ghost.conf
# ------------------------------------------------------------------------------
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Notification settings
NOTIFICATIONS_ENABLED="${NOTIFICATIONS_ENABLED:-true}"
NOTIFY_ON_FINDING="${NOTIFY_ON_FINDING:-true}"
NOTIFY_ON_COMPLETION="${NOTIFY_ON_COMPLETION:-true}"
NOTIFY_RATE_LIMIT="${NOTIFY_RATE_LIMIT:-5}"  # Minimum seconds between notifications

# Track last notification time to prevent spam
_LAST_NOTIFICATION_TIME=0

# ------------------------------------------------------------------------------
# _can_send_notification()
# Check rate limiting before sending
# Returns: 0 if can send, 1 if rate limited
# ------------------------------------------------------------------------------
_can_send_notification() {
    if [ "$NOTIFICATIONS_ENABLED" != "true" ]; then
        return 1
    fi
    
    local current_time
    current_time=$(date +%s)
    local time_diff=$((current_time - _LAST_NOTIFICATION_TIME))
    
    if [ "$time_diff" -lt "$NOTIFY_RATE_LIMIT" ]; then
        return 1
    fi
    
    _LAST_NOTIFICATION_TIME=$current_time
    return 0
}

# ------------------------------------------------------------------------------
# _escape_json()
# Escape special characters for JSON
# Arguments: $1 = String to escape
# Returns: Escaped string
# ------------------------------------------------------------------------------
_escape_json() {
    local string="$1"
    # Escape backslashes, quotes, and newlines
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    string="${string//$'\n'/\\n}"
    string="${string//$'\r'/\\r}"
    string="${string//$'\t'/\\t}"
    echo "$string"
}

# ------------------------------------------------------------------------------
# send_discord()
# Send a notification to Discord via webhook
# Arguments: $1 = Title, $2 = Message, $3 = Color (optional, hex without #)
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
send_discord() {
    local title="$1"
    local message="$2"
    local color="${3:-3447003}"  # Default blue color
    
    if [ -z "$DISCORD_WEBHOOK_URL" ]; then
        log_debug "Discord webhook not configured"
        return 1
    fi
    
    if ! _can_send_notification; then
        log_debug "Discord notification rate limited"
        return 1
    fi
    
    # Escape message for JSON
    title=$(_escape_json "$title")
    message=$(_escape_json "$message")
    
    # Build Discord embed payload
    local payload
    payload=$(cat << EOF
{
    "embeds": [{
        "title": "${title}",
        "description": "${message}",
        "color": ${color},
        "footer": {
            "text": "GHOST-FRAMEWORK v${GHOST_VERSION:-1.0.0}"
        },
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }]
}
EOF
)
    
    # Send webhook request
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$DISCORD_WEBHOOK_URL" 2>/dev/null)
    
    if [ "$response" = "204" ] || [ "$response" = "200" ]; then
        log_debug "Discord notification sent successfully"
        return 0
    else
        log_warn "Failed to send Discord notification (HTTP $response)"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# send_slack()
# Send a notification to Slack via webhook
# Arguments: $1 = Title, $2 = Message, $3 = Color (optional)
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
send_slack() {
    local title="$1"
    local message="$2"
    local color="${3:-#3498db}"  # Default blue
    
    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        log_debug "Slack webhook not configured"
        return 1
    fi
    
    if ! _can_send_notification; then
        log_debug "Slack notification rate limited"
        return 1
    fi
    
    # Escape for JSON
    title=$(_escape_json "$title")
    message=$(_escape_json "$message")
    
    # Build Slack attachment payload
    local payload
    payload=$(cat << EOF
{
    "attachments": [{
        "color": "${color}",
        "title": "${title}",
        "text": "${message}",
        "footer": "GHOST-FRAMEWORK v${GHOST_VERSION:-1.0.0}",
        "ts": $(date +%s)
    }]
}
EOF
)
    
    # Send webhook request
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$SLACK_WEBHOOK_URL" 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        log_debug "Slack notification sent successfully"
        return 0
    else
        log_warn "Failed to send Slack notification (HTTP $response)"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# send_telegram()
# Send a notification to Telegram via Bot API
# Arguments: $1 = Message
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
send_telegram() {
    local message="$1"
    
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        log_debug "Telegram not configured"
        return 1
    fi
    
    if ! _can_send_notification; then
        log_debug "Telegram notification rate limited"
        return 1
    fi
    
    # Telegram Bot API URL
    local api_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    
    # Escape for URL encoding (basic)
    message=$(_escape_json "$message")
    
    # Send request
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"🔍 GHOST-FRAMEWORK\\n\\n${message}\", \"parse_mode\": \"HTML\"}" \
        "$api_url" 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        log_debug "Telegram notification sent successfully"
        return 0
    else
        log_warn "Failed to send Telegram notification (HTTP $response)"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# notify_all()
# Send notification to all configured channels
# Arguments: $1 = Title, $2 = Message, $3 = Severity (info/warning/critical)
# ------------------------------------------------------------------------------
notify_all() {
    local title="$1"
    local message="$2"
    local severity="${3:-info}"
    
    # Determine colors based on severity
    local discord_color slack_color
    case "$severity" in
        "critical")
            discord_color="15158332"  # Red
            slack_color="#e74c3c"
            ;;
        "warning")
            discord_color="15844367"  # Orange
            slack_color="#f39c12"
            ;;
        "success")
            discord_color="3066993"   # Green
            slack_color="#27ae60"
            ;;
        *)
            discord_color="3447003"   # Blue
            slack_color="#3498db"
            ;;
    esac
    
    # Send to all channels (don't wait for response)
    send_discord "$title" "$message" "$discord_color" &
    send_slack "$title" "$message" "$slack_color" &
    send_telegram "${title}\\n${message}" &
    
    # Wait for background processes
    wait
}

# ------------------------------------------------------------------------------
# notify_finding()
# Notify about a security finding
# Arguments: $1 = Severity, $2 = Vulnerability type, $3 = Target, $4 = Details
# ------------------------------------------------------------------------------
notify_finding() {
    local severity="$1"
    local vuln_type="$2"
    local target="$3"
    local details="$4"
    
    if [ "$NOTIFY_ON_FINDING" != "true" ]; then
        return
    fi
    
    local title="🚨 ${severity} Finding: ${vuln_type}"
    local message="**Target:** ${target}\\n**Details:** ${details}"
    
    local notify_severity
    case "$severity" in
        "CRITICAL"|"HIGH") notify_severity="critical" ;;
        "MEDIUM")          notify_severity="warning" ;;
        *)                 notify_severity="info" ;;
    esac
    
    notify_all "$title" "$message" "$notify_severity"
}

# ------------------------------------------------------------------------------
# notify_scan_complete()
# Notify that a scan has completed
# Arguments: $1 = Target domain, $2 = Summary stats
# ------------------------------------------------------------------------------
notify_scan_complete() {
    local domain="$1"
    local summary="$2"
    
    if [ "$NOTIFY_ON_COMPLETION" != "true" ]; then
        return
    fi
    
    local title="✅ Scan Complete: ${domain}"
    notify_all "$title" "$summary" "success"
}

# ------------------------------------------------------------------------------
# notify_error()
# Notify about a critical error
# Arguments: $1 = Error message
# ------------------------------------------------------------------------------
notify_error() {
    local error_msg="$1"
    notify_all "❌ GHOST-FRAMEWORK Error" "$error_msg" "critical"
}

# ------------------------------------------------------------------------------
# test_notifications()
# Send a test notification to all configured channels
# ------------------------------------------------------------------------------
test_notifications() {
    echo "Testing notification channels..."
    
    local test_msg="This is a test notification from GHOST-FRAMEWORK"
    
    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        echo -n "Discord: "
        if send_discord "Test Notification" "$test_msg"; then
            echo "✓ Success"
        else
            echo "✗ Failed"
        fi
    else
        echo "Discord: Not configured"
    fi
    
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        echo -n "Slack: "
        if send_slack "Test Notification" "$test_msg"; then
            echo "✓ Success"
        else
            echo "✗ Failed"
        fi
    else
        echo "Slack: Not configured"
    fi
    
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo -n "Telegram: "
        if send_telegram "$test_msg"; then
            echo "✓ Success"
        else
            echo "✗ Failed"
        fi
    else
        echo "Telegram: Not configured"
    fi
}
