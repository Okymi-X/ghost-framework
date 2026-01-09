#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Scheduler Module
# ==============================================================================
# File: utils/scheduler.sh
# Description: Schedule and automate recurring scans
# License: MIT
# Version: 1.3.0
# ==============================================================================

# Scheduler configuration
SCHEDULER_DIR="${SCHEDULER_DIR:-$HOME/.ghost-scheduler}"
SCHEDULER_LOG="$SCHEDULER_DIR/scheduler.log"

# ------------------------------------------------------------------------------
# init_scheduler()
# Initialize scheduler directory
# ------------------------------------------------------------------------------
init_scheduler() {
    mkdir -p "$SCHEDULER_DIR"
    touch "$SCHEDULER_LOG"
    log_debug "Scheduler initialized: $SCHEDULER_DIR"
}

# ------------------------------------------------------------------------------
# add_scheduled_scan()
# Add a new scheduled scan
# Arguments: $1 = Domain, $2 = Cron expression, $3 = Scan mode
# ------------------------------------------------------------------------------
add_scheduled_scan() {
    local domain="$1"
    local cron_expr="$2"
    local mode="${3:-stealth}"
    
    init_scheduler
    
    local ghost_path
    ghost_path=$(readlink -f "${BASH_SOURCE[0]%/*}/../ghost.sh")
    
    local job_id
    job_id=$(date +%s | md5sum | cut -c1-8)
    
    # Create job file
    cat > "$SCHEDULER_DIR/job_${job_id}.conf" << EOF
DOMAIN="$domain"
CRON="$cron_expr"
MODE="$mode"
CREATED="$(date -Iseconds)"
GHOST_PATH="$ghost_path"
ENABLED="true"
EOF
    
    echo "Job created: $job_id for $domain"
    echo "Cron: $cron_expr"
}

# ------------------------------------------------------------------------------
# list_scheduled_scans()
# List all scheduled scans
# ------------------------------------------------------------------------------
list_scheduled_scans() {
    init_scheduler
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "              GHOST-FRAMEWORK - Scheduled Scans"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    for job in "$SCHEDULER_DIR"/job_*.conf; do
        [ -f "$job" ] || continue
        
        local job_id
        job_id=$(basename "$job" .conf | sed 's/job_//')
        
        source "$job"
        
        local status="✅ Active"
        [ "$ENABLED" != "true" ] && status="⏸️ Paused"
        
        echo "[$job_id] $DOMAIN"
        echo "  └─ Cron: $CRON | Mode: $MODE | $status"
        echo ""
    done
}

# ------------------------------------------------------------------------------
# remove_scheduled_scan()
# Remove a scheduled scan
# Arguments: $1 = Job ID
# ------------------------------------------------------------------------------
remove_scheduled_scan() {
    local job_id="$1"
    
    if [ -f "$SCHEDULER_DIR/job_${job_id}.conf" ]; then
        rm -f "$SCHEDULER_DIR/job_${job_id}.conf"
        echo "Job $job_id removed"
    else
        echo "Job $job_id not found"
    fi
}

# ------------------------------------------------------------------------------
# generate_cron_entry()
# Generate cron entry for system crontab
# Arguments: $1 = Job ID
# ------------------------------------------------------------------------------
generate_cron_entry() {
    local job_id="$1"
    local job_file="$SCHEDULER_DIR/job_${job_id}.conf"
    
    if [ ! -f "$job_file" ]; then
        echo "Job $job_id not found"
        return 1
    fi
    
    source "$job_file"
    
    echo "$CRON $GHOST_PATH -d $DOMAIN -m $MODE >> $SCHEDULER_LOG 2>&1"
}

# ------------------------------------------------------------------------------
# install_cron_jobs()
# Install all scheduled scans to system crontab
# ------------------------------------------------------------------------------
install_cron_jobs() {
    init_scheduler
    
    local temp_cron
    temp_cron=$(mktemp)
    
    # Preserve existing cron jobs
    crontab -l 2>/dev/null | grep -v "GHOST-FRAMEWORK" > "$temp_cron" || true
    
    echo "# GHOST-FRAMEWORK Scheduled Scans" >> "$temp_cron"
    
    for job in "$SCHEDULER_DIR"/job_*.conf; do
        [ -f "$job" ] || continue
        
        source "$job"
        [ "$ENABLED" != "true" ] && continue
        
        echo "$CRON $GHOST_PATH -d $DOMAIN -m $MODE >> $SCHEDULER_LOG 2>&1 # GHOST-FRAMEWORK" >> "$temp_cron"
    done
    
    crontab "$temp_cron"
    rm -f "$temp_cron"
    
    echo "Cron jobs installed. Use 'crontab -l' to verify."
}

# ------------------------------------------------------------------------------
# run_scheduler_daemon()
# Simple scheduler daemon (alternative to cron)
# ------------------------------------------------------------------------------
run_scheduler_daemon() {
    init_scheduler
    
    echo "GHOST Scheduler starting..."
    echo "Press Ctrl+C to stop"
    
    while true; do
        for job in "$SCHEDULER_DIR"/job_*.conf; do
            [ -f "$job" ] || continue
            
            source "$job"
            [ "$ENABLED" != "true" ] && continue
            
            # Check if it's time to run (simplified, every hour check)
            local hour=$(date +%H)
            local cron_hour=$(echo "$CRON" | awk '{print $2}')
            
            if [ "$cron_hour" = "*" ] || [ "$cron_hour" = "$hour" ]; then
                echo "[$(date)] Running scan for $DOMAIN..."
                "$GHOST_PATH" -d "$DOMAIN" -m "$MODE" >> "$SCHEDULER_LOG" 2>&1 &
            fi
        done
        
        # Sleep for 1 hour
        sleep 3600
    done
}

# ------------------------------------------------------------------------------
# show_scheduler_help()
# Display scheduler help
# ------------------------------------------------------------------------------
show_scheduler_help() {
    echo ""
    echo "GHOST-FRAMEWORK Scheduler"
    echo ""
    echo "Usage:"
    echo "  ghost.sh --schedule add <domain> <cron> [mode]"
    echo "  ghost.sh --schedule list"
    echo "  ghost.sh --schedule remove <job_id>"
    echo "  ghost.sh --schedule install"
    echo ""
    echo "Examples:"
    echo "  # Daily scan at midnight"
    echo "  ghost.sh --schedule add example.com '0 0 * * *' stealth"
    echo ""
    echo "  # Weekly scan on Sunday at 2 AM"
    echo "  ghost.sh --schedule add target.com '0 2 * * 0' aggressive"
    echo ""
    echo "  # Install jobs to system crontab"
    echo "  ghost.sh --schedule install"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_scheduler_help
fi
