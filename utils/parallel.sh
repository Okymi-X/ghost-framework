#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Parallel Executor Module
# ==============================================================================
# File: utils/parallel.sh
# Description: Job queue and parallel execution management
# License: MIT
# Version: 1.3.0
# ==============================================================================

# Default parallel settings
PARALLEL_JOBS="${PARALLEL_JOBS:-5}"
PARALLEL_TIMEOUT="${PARALLEL_TIMEOUT:-300}"

# Job tracking
declare -A JOB_PIDS
declare -A JOB_STATUS
JOB_QUEUE=()

# ------------------------------------------------------------------------------
# init_parallel()
# Initialize parallel executor
# Arguments: $1 = Max parallel jobs (optional)
# ------------------------------------------------------------------------------
init_parallel() {
    local max_jobs="${1:-$PARALLEL_JOBS}"
    
    PARALLEL_JOBS="$max_jobs"
    JOB_PIDS=()
    JOB_STATUS=()
    JOB_QUEUE=()
    
    log_debug "Parallel executor initialized (max $max_jobs jobs)"
}

# ------------------------------------------------------------------------------
# add_job()
# Add a job to the queue
# Arguments: $1 = Job name, $2 = Command to execute
# ------------------------------------------------------------------------------
add_job() {
    local job_name="$1"
    local command="$2"
    
    JOB_QUEUE+=("$job_name:$command")
    log_debug "Job queued: $job_name"
}

# ------------------------------------------------------------------------------
# run_job()
# Execute a single job in background
# Arguments: $1 = Job name, $2 = Command
# ------------------------------------------------------------------------------
run_job() {
    local job_name="$1"
    local command="$2"
    
    # Execute in background
    (
        eval "$command"
    ) &
    
    local pid=$!
    JOB_PIDS["$job_name"]=$pid
    JOB_STATUS["$job_name"]="running"
    
    log_debug "Job started: $job_name (PID: $pid)"
}

# ------------------------------------------------------------------------------
# wait_for_slot()
# Wait until a job slot is available
# ------------------------------------------------------------------------------
wait_for_slot() {
    while true; do
        local running=0
        
        for job_name in "${!JOB_PIDS[@]}"; do
            local pid="${JOB_PIDS[$job_name]}"
            
            if kill -0 "$pid" 2>/dev/null; then
                running=$((running + 1))
            else
                # Job completed
                wait "$pid"
                local exit_code=$?
                
                if [ "$exit_code" -eq 0 ]; then
                    JOB_STATUS["$job_name"]="completed"
                else
                    JOB_STATUS["$job_name"]="failed"
                fi
                
                unset JOB_PIDS["$job_name"]
            fi
        done
        
        if [ "$running" -lt "$PARALLEL_JOBS" ]; then
            break
        fi
        
        sleep 0.5
    done
}

# ------------------------------------------------------------------------------
# process_queue()
# Process all jobs in the queue with parallel execution
# ------------------------------------------------------------------------------
process_queue() {
    log_info "Processing ${#JOB_QUEUE[@]} jobs (max $PARALLEL_JOBS parallel)..."
    
    local total=${#JOB_QUEUE[@]}
    local processed=0
    
    for job_entry in "${JOB_QUEUE[@]}"; do
        # Parse job entry
        local job_name="${job_entry%%:*}"
        local command="${job_entry#*:}"
        
        # Wait for available slot
        wait_for_slot
        
        # Run job
        run_job "$job_name" "$command"
        processed=$((processed + 1))
        
        log_debug "Progress: $processed/$total jobs started"
    done
    
    # Wait for all remaining jobs
    wait_all
    
    # Clear queue
    JOB_QUEUE=()
}

# ------------------------------------------------------------------------------
# wait_all()
# Wait for all running jobs to complete
# ------------------------------------------------------------------------------
wait_all() {
    log_debug "Waiting for all jobs to complete..."
    
    for job_name in "${!JOB_PIDS[@]}"; do
        local pid="${JOB_PIDS[$job_name]}"
        
        if kill -0 "$pid" 2>/dev/null; then
            wait "$pid"
            local exit_code=$?
            
            if [ "$exit_code" -eq 0 ]; then
                JOB_STATUS["$job_name"]="completed"
            else
                JOB_STATUS["$job_name"]="failed"
            fi
        fi
    done
    
    JOB_PIDS=()
}

# ------------------------------------------------------------------------------
# get_job_status()
# Get status of a specific job
# Arguments: $1 = Job name
# Returns: Job status
# ------------------------------------------------------------------------------
get_job_status() {
    local job_name="$1"
    echo "${JOB_STATUS[$job_name]:-unknown}"
}

# ------------------------------------------------------------------------------
# get_job_summary()
# Get summary of all job statuses
# Returns: Summary string
# ------------------------------------------------------------------------------
get_job_summary() {
    local completed=0
    local failed=0
    local running=0
    
    for status in "${JOB_STATUS[@]}"; do
        case "$status" in
            completed) completed=$((completed + 1)) ;;
            failed) failed=$((failed + 1)) ;;
            running) running=$((running + 1)) ;;
        esac
    done
    
    echo "Completed: $completed | Failed: $failed | Running: $running"
}

# ------------------------------------------------------------------------------
# parallel_curl()
# Execute multiple curl requests in parallel
# Arguments: $1 = URLs file, $2 = Output directory, $3 = Additional curl options
# ------------------------------------------------------------------------------
parallel_curl() {
    local urls_file="$1"
    local output_dir="$2"
    local curl_opts="${3:-}"
    
    if [ ! -f "$urls_file" ]; then
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    init_parallel
    
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        
        local filename
        filename=$(echo "$url" | md5sum | cut -d' ' -f1)
        
        add_job "curl_$filename" "curl -s $curl_opts '$url' -o '$output_dir/$filename.txt' 2>/dev/null"
        
    done < "$urls_file"
    
    process_queue
}

# ------------------------------------------------------------------------------
# parallel_scan_hosts()
# Scan multiple hosts in parallel
# Arguments: $1 = Hosts file, $2 = Scan function, $3 = Output directory
# ------------------------------------------------------------------------------
parallel_scan_hosts() {
    local hosts_file="$1"
    local scan_function="$2"
    local output_dir="$3"
    
    if [ ! -f "$hosts_file" ]; then
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    init_parallel
    
    while IFS= read -r host; do
        [ -z "$host" ] && continue
        
        local safe_host
        safe_host=$(echo "$host" | tr -c 'a-zA-Z0-9-' '_')
        
        add_job "scan_$safe_host" "$scan_function '$host' '$output_dir/${safe_host}.txt'"
        
    done < "$hosts_file"
    
    process_queue
    
    echo ""
    log_info "Parallel scan complete: $(get_job_summary)"
}

# ------------------------------------------------------------------------------
# xargs_parallel()
# Use xargs for simple parallel execution (fallback)
# Arguments: $1 = Input file, $2 = Command template (use {} for input)
# ------------------------------------------------------------------------------
xargs_parallel() {
    local input_file="$1"
    local command_template="$2"
    local max_procs="${3:-$PARALLEL_JOBS}"
    
    if [ ! -f "$input_file" ]; then
        return 1
    fi
    
    cat "$input_file" | xargs -I {} -P "$max_procs" bash -c "$command_template"
}

# ------------------------------------------------------------------------------
# gnu_parallel()
# Use GNU parallel if available (more features)
# Arguments: $1 = Input file, $2 = Command
# ------------------------------------------------------------------------------
gnu_parallel() {
    local input_file="$1"
    local command="$2"
    
    if ! command -v parallel &>/dev/null; then
        log_warn "GNU parallel not installed, using xargs"
        xargs_parallel "$input_file" "$command"
        return
    fi
    
    parallel -j "$PARALLEL_JOBS" --bar "$command" < "$input_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Parallel Executor"
    echo ""
    echo "Usage:"
    echo "  source parallel.sh"
    echo "  init_parallel [max_jobs]"
    echo "  add_job <name> <command>"
    echo "  process_queue"
fi
