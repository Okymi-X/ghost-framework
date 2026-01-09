#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Logging Utilities
# ==============================================================================
# File: utils/logger.sh
# Description: Timestamped logging functions with file and stdout output
# License: MIT
# ==============================================================================

# ------------------------------------------------------------------------------
# Logging Configuration
# These can be overridden by sourcing config before this file
# ------------------------------------------------------------------------------
LOG_FILE="${LOG_FILE:-/tmp/ghost_$(date +%Y%m%d_%H%M%S).log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_TO_FILE="${LOG_TO_FILE:-true}"
LOG_TO_STDOUT="${LOG_TO_STDOUT:-true}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"  # 10MB default

# Log level hierarchy (lower number = more verbose)
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

# Colors for log levels (requires banner.sh to be sourced first)
declare -A LOG_COLORS=(
    ["DEBUG"]="\033[0;35m"      # Magenta
    ["INFO"]="\033[0;34m"       # Blue
    ["WARN"]="\033[0;33m"       # Yellow
    ["ERROR"]="\033[0;31m"      # Red
    ["CRITICAL"]="\033[1;31m"   # Bold Red
)

readonly COLOR_RESET_LOG='\033[0m'

# ------------------------------------------------------------------------------
# init_logging()
# Initialize the logging system, create log file and directory
# Arguments: $1 = Log file path (optional, uses LOG_FILE if not provided)
# ------------------------------------------------------------------------------
init_logging() {
    local log_path="${1:-$LOG_FILE}"
    LOG_FILE="$log_path"
    
    # Create log directory if it doesn't exist
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "Warning: Could not create log directory $log_dir"
            LOG_FILE="/tmp/ghost_$(date +%Y%m%d_%H%M%S).log"
        }
    fi
    
    # Create or truncate log file
    : > "$LOG_FILE" 2>/dev/null || {
        echo "Warning: Could not create log file $LOG_FILE"
        LOG_TO_FILE="false"
    }
    
    # Log session start
    _write_log "INFO" "═══════════════════════════════════════════════════════════"
    _write_log "INFO" "GHOST-FRAMEWORK Logging Session Started"
    _write_log "INFO" "Log File: $LOG_FILE"
    _write_log "INFO" "Log Level: $LOG_LEVEL"
    _write_log "INFO" "═══════════════════════════════════════════════════════════"
}

# ------------------------------------------------------------------------------
# _get_timestamp()
# Get current timestamp in ISO 8601 format
# Returns: Timestamp string
# ------------------------------------------------------------------------------
_get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# ------------------------------------------------------------------------------
# _should_log()
# Check if a message should be logged based on current log level
# Arguments: $1 = Message log level
# Returns: 0 if should log, 1 if should not
# ------------------------------------------------------------------------------
_should_log() {
    local msg_level="$1"
    local current_level="${LOG_LEVELS[$LOG_LEVEL]:-1}"
    local msg_level_num="${LOG_LEVELS[$msg_level]:-1}"
    
    [ "$msg_level_num" -ge "$current_level" ]
}

# ------------------------------------------------------------------------------
# _rotate_log()
# Rotate log file if it exceeds maximum size
# ------------------------------------------------------------------------------
_rotate_log() {
    if [ "$LOG_TO_FILE" != "true" ] || [ ! -f "$LOG_FILE" ]; then
        return
    fi
    
    local size
    size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    
    if [ "$size" -gt "$LOG_MAX_SIZE" ]; then
        local backup="${LOG_FILE}.$(date +%Y%m%d_%H%M%S).bak"
        mv "$LOG_FILE" "$backup" 2>/dev/null
        : > "$LOG_FILE"
        _write_log "INFO" "Log rotated. Previous log: $backup"
    fi
}

# ------------------------------------------------------------------------------
# _write_log()
# Internal function to write log entry
# Arguments: $1 = Level, $2 = Message
# ------------------------------------------------------------------------------
_write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(_get_timestamp)
    
    # Check log rotation
    _rotate_log
    
    # Format: [TIMESTAMP] [LEVEL] Message
    local log_entry="[${timestamp}] [${level}] ${message}"
    
    # Write to file if enabled
    if [ "$LOG_TO_FILE" = "true" ] && [ -n "$LOG_FILE" ]; then
        echo "$log_entry" >> "$LOG_FILE" 2>/dev/null
    fi
    
    # Write to stdout if enabled
    if [ "$LOG_TO_STDOUT" = "true" ]; then
        local color="${LOG_COLORS[$level]:-$COLOR_RESET_LOG}"
        echo -e "${color}[${level}]${COLOR_RESET_LOG} ${message}"
    fi
}

# ------------------------------------------------------------------------------
# Public Logging Functions
# Usage: log_info "Your message here"
# ------------------------------------------------------------------------------

log_debug() {
    if _should_log "DEBUG"; then
        _write_log "DEBUG" "$1"
    fi
}

log_info() {
    if _should_log "INFO"; then
        _write_log "INFO" "$1"
    fi
}

log_warn() {
    if _should_log "WARN"; then
        _write_log "WARN" "$1"
    fi
}

log_error() {
    if _should_log "ERROR"; then
        _write_log "ERROR" "$1"
    fi
}

log_critical() {
    if _should_log "CRITICAL"; then
        _write_log "CRITICAL" "$1"
    fi
}

# ------------------------------------------------------------------------------
# log_command()
# Log a command execution with its output
# Arguments: $1 = Command description, $2... = Command to execute
# Returns: Exit code of command
# ------------------------------------------------------------------------------
log_command() {
    local desc="$1"
    shift
    local cmd="$*"
    
    log_debug "Executing: $cmd"
    log_info "$desc"
    
    local output
    local exit_code
    output=$("$@" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_debug "Command output: $output"
        log_debug "Command completed successfully"
    else
        log_error "Command failed with exit code $exit_code"
        log_error "Output: $output"
    fi
    
    return $exit_code
}

# ------------------------------------------------------------------------------
# log_separator()
# Log a visual separator line
# Arguments: $1 = Character to use (optional, defaults to ─)
# ------------------------------------------------------------------------------
log_separator() {
    local char="${1:-─}"
    local line=""
    for _ in $(seq 1 60); do
        line="${line}${char}"
    done
    log_info "$line"
}

# ------------------------------------------------------------------------------
# log_section()
# Log a section header
# Arguments: $1 = Section title
# ------------------------------------------------------------------------------
log_section() {
    local title="$1"
    log_info ""
    log_separator "═"
    log_info "  $title"
    log_separator "═"
}

# ------------------------------------------------------------------------------
# log_findings()
# Log security findings in a structured format
# Arguments: $1 = Severity, $2 = Title, $3 = Details
# ------------------------------------------------------------------------------
log_findings() {
    local severity="$1"
    local title="$2"
    local details="$3"
    
    local color
    case "$severity" in
        "CRITICAL") color="\033[1;31m" ;;
        "HIGH")     color="\033[0;31m" ;;
        "MEDIUM")   color="\033[0;33m" ;;
        "LOW")      color="\033[0;34m" ;;
        "INFO")     color="\033[0;32m" ;;
        *)          color="\033[0m" ;;
    esac
    
    echo -e "${color}[${severity}]${COLOR_RESET_LOG} ${title}"
    if [ -n "$details" ]; then
        echo -e "    └─ ${details}"
    fi
    
    # Also log to file
    if [ "$LOG_TO_FILE" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FINDING:${severity}] ${title} - ${details}" >> "$LOG_FILE"
    fi
}

# ------------------------------------------------------------------------------
# get_log_file()
# Return the current log file path
# ------------------------------------------------------------------------------
get_log_file() {
    echo "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# tail_log()
# Display the last N lines of the log file
# Arguments: $1 = Number of lines (default 20)
# ------------------------------------------------------------------------------
tail_log() {
    local lines="${1:-20}"
    if [ -f "$LOG_FILE" ]; then
        tail -n "$lines" "$LOG_FILE"
    else
        echo "No log file found at $LOG_FILE"
    fi
}
