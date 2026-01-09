#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Resume Capability Module
# ==============================================================================
# File: utils/resume.sh
# Description: Save and resume interrupted scans
# License: MIT
# Version: 1.3.0
# ==============================================================================

# State file name
readonly STATE_FILE="ghost_state.json"

# ------------------------------------------------------------------------------
# save_scan_state()
# Save current scan state to file
# Arguments: $1 = Workspace, $2 = Current phase, $3 = Additional data (JSON)
# ------------------------------------------------------------------------------
save_scan_state() {
    local workspace="$1"
    local current_phase="$2"
    local additional_data="${3:-{}}"
    
    local state_path="$workspace/$STATE_FILE"
    
    local state
    state=$(cat <<EOF
{
    "version": "${GHOST_VERSION:-1.3.0}",
    "target_domain": "${TARGET_DOMAIN:-}",
    "workspace": "$workspace",
    "current_phase": "$current_phase",
    "started_at": "${SCAN_START_TIME:-$(date -Iseconds)}",
    "saved_at": "$(date -Iseconds)",
    "scan_mode": "${SCAN_MODE:-stealth}",
    "is_waf": "${IS_WAF:-false}",
    "waf_provider": "${WAF_PROVIDER:-}",
    "completed_phases": $(get_completed_phases_json),
    "config": {
        "threads": "${THREADS:-10}",
        "rate_limit": "${RATE_LIMIT:-100}",
        "timeout": "${TIMEOUT:-30}"
    },
    "additional": $additional_data
}
EOF
)
    
    echo "$state" > "$state_path"
    log_debug "Scan state saved to $state_path"
}

# ------------------------------------------------------------------------------
# get_completed_phases_json()
# Get completed phases as JSON array
# Returns: JSON array of completed phases
# ------------------------------------------------------------------------------
get_completed_phases_json() {
    local phases=()
    
    [ "${PHASE_RECON_COMPLETE:-false}" = "true" ] && phases+=("recon")
    [ "${PHASE_TAKEOVER_COMPLETE:-false}" = "true" ] && phases+=("takeover")
    [ "${PHASE_PORTSCAN_COMPLETE:-false}" = "true" ] && phases+=("portscan")
    [ "${PHASE_CRAWL_COMPLETE:-false}" = "true" ] && phases+=("crawl")
    [ "${PHASE_SECRETS_COMPLETE:-false}" = "true" ] && phases+=("secrets")
    [ "${PHASE_FUZZING_COMPLETE:-false}" = "true" ] && phases+=("fuzzing")
    [ "${PHASE_SCREENSHOTS_COMPLETE:-false}" = "true" ] && phases+=("screenshots")
    [ "${PHASE_CLOUD_COMPLETE:-false}" = "true" ] && phases+=("cloud")
    [ "${PHASE_GITHUB_COMPLETE:-false}" = "true" ] && phases+=("github")
    [ "${PHASE_VULN_COMPLETE:-false}" = "true" ] && phases+=("vuln")
    
    printf '["%s"]' "$(IFS=','; echo "${phases[*]}" | sed 's/,/","/g')"
}

# ------------------------------------------------------------------------------
# load_scan_state()
# Load scan state from file
# Arguments: $1 = Workspace or state file path
# Returns: 0 if loaded, 1 if not found
# ------------------------------------------------------------------------------
load_scan_state() {
    local path="$1"
    
    # Check if path is a file or directory
    if [ -d "$path" ]; then
        path="$path/$STATE_FILE"
    fi
    
    if [ ! -f "$path" ]; then
        log_warn "No saved state found at $path"
        return 1
    fi
    
    log_info "Loading saved scan state..."
    
    if ! command -v jq &>/dev/null; then
        log_error "jq required for state management"
        return 1
    fi
    
    # Load state
    local state
    state=$(cat "$path")
    
    # Restore environment
    export TARGET_DOMAIN=$(echo "$state" | jq -r '.target_domain')
    export WORKSPACE=$(echo "$state" | jq -r '.workspace')
    export SCAN_MODE=$(echo "$state" | jq -r '.scan_mode')
    export IS_WAF=$(echo "$state" | jq -r '.is_waf')
    export WAF_PROVIDER=$(echo "$state" | jq -r '.waf_provider')
    export SCAN_START_TIME=$(echo "$state" | jq -r '.started_at')
    
    local resume_phase
    resume_phase=$(echo "$state" | jq -r '.current_phase')
    export RESUME_FROM_PHASE="$resume_phase"
    
    # Mark completed phases
    local completed
    completed=$(echo "$state" | jq -r '.completed_phases[]?' 2>/dev/null)
    
    for phase in $completed; do
        case "$phase" in
            recon) export PHASE_RECON_COMPLETE="true" ;;
            takeover) export PHASE_TAKEOVER_COMPLETE="true" ;;
            portscan) export PHASE_PORTSCAN_COMPLETE="true" ;;
            crawl) export PHASE_CRAWL_COMPLETE="true" ;;
            secrets) export PHASE_SECRETS_COMPLETE="true" ;;
            fuzzing) export PHASE_FUZZING_COMPLETE="true" ;;
            screenshots) export PHASE_SCREENSHOTS_COMPLETE="true" ;;
            cloud) export PHASE_CLOUD_COMPLETE="true" ;;
            github) export PHASE_GITHUB_COMPLETE="true" ;;
            vuln) export PHASE_VULN_COMPLETE="true" ;;
        esac
    done
    
    log_success "State loaded. Resume from: $resume_phase"
    log_info "Target: $TARGET_DOMAIN"
    log_info "Workspace: $WORKSPACE"
    
    return 0
}

# ------------------------------------------------------------------------------
# should_skip_phase()
# Check if a phase should be skipped (already completed)
# Arguments: $1 = Phase name
# Returns: 0 if should skip, 1 if should run
# ------------------------------------------------------------------------------
should_skip_phase() {
    local phase="$1"
    
    case "$phase" in
        recon) [ "${PHASE_RECON_COMPLETE:-false}" = "true" ] && return 0 ;;
        takeover) [ "${PHASE_TAKEOVER_COMPLETE:-false}" = "true" ] && return 0 ;;
        portscan) [ "${PHASE_PORTSCAN_COMPLETE:-false}" = "true" ] && return 0 ;;
        crawl) [ "${PHASE_CRAWL_COMPLETE:-false}" = "true" ] && return 0 ;;
        secrets) [ "${PHASE_SECRETS_COMPLETE:-false}" = "true" ] && return 0 ;;
        fuzzing) [ "${PHASE_FUZZING_COMPLETE:-false}" = "true" ] && return 0 ;;
        screenshots) [ "${PHASE_SCREENSHOTS_COMPLETE:-false}" = "true" ] && return 0 ;;
        cloud) [ "${PHASE_CLOUD_COMPLETE:-false}" = "true" ] && return 0 ;;
        github) [ "${PHASE_GITHUB_COMPLETE:-false}" = "true" ] && return 0 ;;
        vuln) [ "${PHASE_VULN_COMPLETE:-false}" = "true" ] && return 0 ;;
    esac
    
    return 1
}

# ------------------------------------------------------------------------------
# mark_phase_complete()
# Mark a phase as complete
# Arguments: $1 = Phase name
# ------------------------------------------------------------------------------
mark_phase_complete() {
    local phase="$1"
    
    case "$phase" in
        recon) export PHASE_RECON_COMPLETE="true" ;;
        takeover) export PHASE_TAKEOVER_COMPLETE="true" ;;
        portscan) export PHASE_PORTSCAN_COMPLETE="true" ;;
        crawl) export PHASE_CRAWL_COMPLETE="true" ;;
        secrets) export PHASE_SECRETS_COMPLETE="true" ;;
        fuzzing) export PHASE_FUZZING_COMPLETE="true" ;;
        screenshots) export PHASE_SCREENSHOTS_COMPLETE="true" ;;
        cloud) export PHASE_CLOUD_COMPLETE="true" ;;
        github) export PHASE_GITHUB_COMPLETE="true" ;;
        vuln) export PHASE_VULN_COMPLETE="true" ;;
    esac
    
    # Auto-save state
    if [ -n "${WORKSPACE:-}" ]; then
        save_scan_state "$WORKSPACE" "$(get_next_phase "$phase")"
    fi
}

# ------------------------------------------------------------------------------
# get_next_phase()
# Get the next phase after the given one
# Arguments: $1 = Current phase
# Returns: Next phase name
# ------------------------------------------------------------------------------
get_next_phase() {
    local current="$1"
    
    local phases=(recon takeover portscan crawl secrets fuzzing screenshots cloud github vuln complete)
    
    local found=false
    for phase in "${phases[@]}"; do
        if [ "$found" = true ]; then
            echo "$phase"
            return
        fi
        [ "$phase" = "$current" ] && found=true
    done
    
    echo "complete"
}

# ------------------------------------------------------------------------------
# clear_state()
# Clear saved state
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
clear_state() {
    local workspace="$1"
    local state_path="$workspace/$STATE_FILE"
    
    if [ -f "$state_path" ]; then
        rm -f "$state_path"
        log_info "Scan state cleared"
    fi
    
    # Clear environment
    unset PHASE_RECON_COMPLETE PHASE_TAKEOVER_COMPLETE PHASE_PORTSCAN_COMPLETE
    unset PHASE_CRAWL_COMPLETE PHASE_SECRETS_COMPLETE PHASE_FUZZING_COMPLETE
    unset PHASE_SCREENSHOTS_COMPLETE PHASE_CLOUD_COMPLETE PHASE_GITHUB_COMPLETE
    unset PHASE_VULN_COMPLETE RESUME_FROM_PHASE
}

# ------------------------------------------------------------------------------
# show_resume_info()
# Display information about a resumable scan
# Arguments: $1 = Workspace or state file
# ------------------------------------------------------------------------------
show_resume_info() {
    local path="$1"
    
    if [ -d "$path" ]; then
        path="$path/$STATE_FILE"
    fi
    
    if [ ! -f "$path" ]; then
        echo "No saved state found"
        return 1
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "              GHOST-FRAMEWORK - Saved Scan"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if command -v jq &>/dev/null; then
        local state
        state=$(cat "$path")
        
        echo "Target:         $(echo "$state" | jq -r '.target_domain')"
        echo "Started:        $(echo "$state" | jq -r '.started_at')"
        echo "Saved:          $(echo "$state" | jq -r '.saved_at')"
        echo "Current Phase:  $(echo "$state" | jq -r '.current_phase')"
        echo "Completed:      $(echo "$state" | jq -r '.completed_phases | join(", ")')"
        echo "WAF Detected:   $(echo "$state" | jq -r '.is_waf')"
    else
        cat "$path"
    fi
    
    echo ""
    echo "To resume: ./ghost.sh --resume $path"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Resume Module"
    echo ""
    echo "Usage:"
    echo "  source resume.sh"
    echo "  save_scan_state <workspace> <phase>"
    echo "  load_scan_state <workspace>"
    echo "  show_resume_info <workspace>"
fi
