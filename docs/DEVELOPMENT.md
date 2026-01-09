# 📘 GHOST-FRAMEWORK - Module Development Guide

> Guide complet pour contribuer et développer des modules personnalisés

---

## 🏗️ Architecture

```
ghost-framework/
├── ghost.sh                 # Point d'entrée CLI
├── config/
│   └── ghost.conf           # Configuration centrale
├── modules/                 # Modules de scan
│   ├── recon.sh             # Reconnaissance
│   ├── crawling.sh          # Crawling URLs
│   ├── vulnerability.sh     # Scan vulnérabilités
│   └── ...
└── utils/                   # Utilitaires partagés
    ├── banner.sh            # Affichage couleurs
    ├── logger.sh            # Journalisation
    ├── notifications.sh     # Webhooks
    └── ...
```

---

## 📝 Structure d'un Module

Chaque module suit cette structure:

```bash
#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - [Module Name] Module
# ==============================================================================
# File: modules/[module].sh
# Description: [What the module does]
# License: MIT
# Version: 1.3.0
# ==============================================================================

# Constants and configuration
readonly MY_CONSTANT="value"
declare -A MY_ARRAY

# ------------------------------------------------------------------------------
# helper_function()
# Description of what this does
# Arguments: $1 = param1, $2 = param2
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
helper_function() {
    local param1="$1"
    local param2="$2"
    
    # Implementation
}

# ------------------------------------------------------------------------------
# run_[module]_scan()
# Main entry point for the module
# Arguments: $1 = Workspace directory
# ------------------------------------------------------------------------------
run_[module]_scan() {
    local workspace="$1"
    
    print_section "[Module Name]"
    log_info "Starting [module] scan..."
    
    # Check if enabled
    if [ "${MODULE_ENABLED:-true}" != "true" ]; then
        log_info "[Module] scan disabled"
        return 0
    fi
    
    # Create output directory
    local output_dir="$workspace/[module]"
    mkdir -p "$output_dir"
    
    # Your scan logic here
    
    # Summary
    print_section "[Module] Complete"
    log_success "Results saved to $output_dir"
    
    return 0
}

# Allow direct execution for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK [Module Name]"
    echo "Usage: source [module].sh && run_[module]_scan <workspace>"
fi
```

---

## 🛠️ Utilitaires Disponibles

### Logger (`utils/logger.sh`)

```bash
# Logging levels
log_debug "Debug message"      # Only in debug mode
log_info "Information"         # Standard info
log_warn "Warning message"     # Yellow warning
log_error "Error message"      # Red error
log_critical "Critical!"       # Red bold, triggers notification
log_success "Success!"         # Green success

# Special logging
log_finding "high" "XSS" "http://example.com" "Reflected XSS in search"
log_command "nuclei -t templates/"
log_separator
log_section "Starting Phase 2"
```

### Banner (`utils/banner.sh`)

```bash
# Colored output
print_success "Message"
print_error "Message"
print_warning "Message"
print_info "Message"
print_debug "Message"
print_critical "Message"

# Sections
print_section "Section Title"
print_step "1" "Step description"
print_progress 50 100 "Processing"

# Tables
print_table_header "Col1" "Col2" "Col3"
print_table_row "val1" "val2" "val3"
print_table_footer
```

### Notifications (`utils/notifications.sh`)

```bash
# Send to all configured channels
notify_finding "critical" "SQLi found" "http://vuln.com" "Injected via id param"
notify_scan_complete "example.com" "100 findings" "details..."
notify_error "Scan failed" "Rate limited by WAF"
```

### Proxy (`utils/proxy.sh`)

```bash
# Connect to proxy
connect_burp                    # Default Burp localhost:8080
connect_zap                     # Default ZAP localhost:8090
enable_proxy "127.0.0.1" 8080   # Custom proxy

# Use proxy in curl
proxy_curl -s "https://target.com"

# Get proxy options for tools
nuclei_opts=$(get_nuclei_proxy_opts)
curl_opts=$(get_curl_proxy_opts)
```

### Parallel (`utils/parallel.sh`)

```bash
# Initialize
init_parallel 10  # Max 10 concurrent jobs

# Add jobs
add_job "job1" "curl -s https://host1.com"
add_job "job2" "curl -s https://host2.com"
add_job "job3" "curl -s https://host3.com"

# Process queue
process_queue

# Check status
get_job_summary  # "Completed: 3 | Failed: 0 | Running: 0"
```

### Resume (`utils/resume.sh`)

```bash
# Save state
save_scan_state "$WORKSPACE" "crawling"

# Load state
load_scan_state "$WORKSPACE"

# Check if phase completed
if should_skip_phase "recon"; then
    log_info "Recon already complete"
fi

# Mark phase done
mark_phase_complete "recon"
```

---

## ✅ Bonnes Pratiques

### 1. WAF Awareness

```bash
run_my_scan() {
    local threads="${THREADS:-10}"
    local delay="${DELAY:-0}"
    
    # Adapt to WAF
    if [ "${IS_WAF:-false}" = "true" ]; then
        threads=$((threads / 4))
        delay=2
        log_warn "WAF detected - reducing speed"
    fi
    
    # Use adapted values
    my_tool --threads "$threads" --delay "$delay" ...
}
```

### 2. Error Handling

```bash
run_scan() {
    # Check prerequisites
    if ! command -v required_tool &>/dev/null; then
        log_error "required_tool not installed"
        return 1
    fi
    
    # Check input files
    if [ ! -f "$workspace/live_hosts.txt" ]; then
        log_warn "No live hosts - skipping"
        return 0
    fi
    
    # Handle command failures
    if ! my_tool -l "$input" -o "$output" 2>/dev/null; then
        log_error "my_tool failed"
        return 1
    fi
    
    return 0
}
```

### 3. Finding Notifications

```bash
# Notify on critical/high findings
if [ "$severity" = "critical" ] || [ "$severity" = "high" ]; then
    notify_finding "$severity" "$finding_type" "$url" "$details"
fi

# Increment counters
increment_finding "$severity"

# At end of module
log_info "Found ${FINDING_COUNTS[critical]:-0} critical issues"
```

### 4. Output Standards

```bash
# Always create module directory
local output_dir="$workspace/mymodule"
mkdir -p "$output_dir"

# Use consistent file names
# findings go to: findings/
# raw data stays in: mymodule/

# Generate summary
{
    echo "═══════════════════════════════════════"
    echo "      GHOST-FRAMEWORK - My Module"
    echo "═══════════════════════════════════════"
    echo "Scan Date: $(date)"
    echo "Target: ${TARGET_DOMAIN:-unknown}"
    echo ""
    echo "Results: $count items found"
} > "$output_dir/summary.txt"
```

---

## 🧪 Testing Your Module

```bash
# 1. Syntax check
bash -n modules/mymodule.sh && echo "✓ Syntax OK"

# 2. Source and test
source modules/mymodule.sh
source utils/logger.sh
source utils/banner.sh
init_logger "/tmp/test.log"
run_mymodule_scan "/tmp/test_workspace"

# 3. Integration test
./ghost.sh -d example.com --debug
```

---

## 🔌 Integration Checklist

1. [ ] Create `modules/mymodule.sh`
2. [ ] Add to `load_modules()` in `ghost.sh`
3. [ ] Add phase in `main()` function
4. [ ] Add config option `MY_MODULE_ENABLED`
5. [ ] Update `config/ghost.conf.example`
6. [ ] Add to README features table
7. [ ] Add to USER_GUIDE.md
8. [ ] Test with `bash -n`
9. [ ] Test with real target

---

## 📚 Examples

### Simple Checker Module

```bash
#!/bin/bash
# modules/robots.sh - Check robots.txt

run_robots_check() {
    local workspace="$1"
    local output="$workspace/robots"
    mkdir -p "$output"
    
    print_section "Robots.txt Checker"
    
    while IFS= read -r host; do
        local response
        response=$(curl -sL --max-time 10 "$host/robots.txt" 2>/dev/null)
        
        if echo "$response" | grep -q "Disallow:"; then
            echo "$host" >> "$output/has_robots.txt"
            echo "$response" > "$output/$(echo "$host" | md5sum | cut -d' ' -f1).txt"
        fi
    done < "$workspace/live_hosts.txt"
    
    log_success "Checked $(wc -l < "$output/has_robots.txt" 2>/dev/null || echo 0) hosts"
}
```

---

<div align="center">

**Happy Hacking! 👻**

</div>
