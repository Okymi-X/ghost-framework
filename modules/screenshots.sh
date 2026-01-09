#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Screenshot Capture Module
# ==============================================================================
# File: modules/screenshots.sh
# Description: Visual reconnaissance with gowitness/aquatone
# License: MIT
# Version: 1.1.0
#
# This module provides:
# - Homepage screenshot capture
# - Organization by status code
# - Visual gallery generation
# - Interesting page detection
# ==============================================================================

# Screenshot tool preference order
readonly SCREENSHOT_TOOLS=("gowitness" "aquatone" "chromium")

# ------------------------------------------------------------------------------
# detect_screenshot_tool()
# Detect which screenshot tool is available
# Returns: Tool name or empty if none
# ------------------------------------------------------------------------------
detect_screenshot_tool() {
    for tool in "${SCREENSHOT_TOOLS[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo "$tool"
            return 0
        fi
    done
    
    # Check for headless chrome
    if command -v google-chrome &>/dev/null || command -v chromium-browser &>/dev/null; then
        echo "chrome"
        return 0
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# run_gowitness()
# Capture screenshots using gowitness
# Arguments: $1 = URLs file, $2 = Output directory
# ------------------------------------------------------------------------------
run_gowitness() {
    local urls_file="$1"
    local output_dir="$2"
    
    log_info "Running gowitness screenshot capture..."
    
    # Build command
    local gowitness_opts="file -f $urls_file"
    
    # Threads
    local threads="${SCREENSHOTS_THREADS:-10}"
    [ "${IS_WAF:-false}" = "true" ] && threads=$((threads / 2))
    gowitness_opts="$gowitness_opts --threads $threads"
    
    # Output directory
    gowitness_opts="$gowitness_opts --screenshot-path $output_dir"
    
    # Timeout
    gowitness_opts="$gowitness_opts --timeout 15"
    
    # Resolution
    gowitness_opts="$gowitness_opts --resolution-x 1920 --resolution-y 1080"
    
    # Execute
    gowitness $gowitness_opts 2>/dev/null
    
    # Generate report
    if [ -d "$output_dir" ]; then
        gowitness report generate --path "$output_dir" 2>/dev/null
    fi
    
    return $?
}

# ------------------------------------------------------------------------------
# run_aquatone()
# Capture screenshots using aquatone
# Arguments: $1 = URLs file, $2 = Output directory
# ------------------------------------------------------------------------------
run_aquatone() {
    local urls_file="$1"
    local output_dir="$2"
    
    log_info "Running aquatone screenshot capture..."
    
    # Threads
    local threads="${SCREENSHOTS_THREADS:-10}"
    [ "${IS_WAF:-false}" = "true" ] && threads=$((threads / 2))
    
    cat "$urls_file" | aquatone -out "$output_dir" -threads "$threads" -silent 2>/dev/null
    
    return $?
}

# ------------------------------------------------------------------------------
# run_chrome_screenshot()
# Capture screenshot using headless Chrome
# Arguments: $1 = URL, $2 = Output file
# ------------------------------------------------------------------------------
run_chrome_screenshot() {
    local url="$1"
    local output_file="$2"
    
    local chrome_cmd=""
    
    if command -v google-chrome &>/dev/null; then
        chrome_cmd="google-chrome"
    elif command -v chromium-browser &>/dev/null; then
        chrome_cmd="chromium-browser"
    elif command -v chromium &>/dev/null; then
        chrome_cmd="chromium"
    else
        return 1
    fi
    
    $chrome_cmd --headless --disable-gpu --screenshot="$output_file" \
        --window-size=1920,1080 --no-sandbox --disable-dev-shm-usage \
        --hide-scrollbars "$url" 2>/dev/null
    
    return $?
}

# ------------------------------------------------------------------------------
# capture_with_chrome()
# Batch screenshot capture with Chrome
# Arguments: $1 = URLs file, $2 = Output directory
# ------------------------------------------------------------------------------
capture_with_chrome() {
    local urls_file="$1"
    local output_dir="$2"
    
    log_info "Capturing screenshots with headless Chrome..."
    
    local count=0
    local total
    total=$(wc -l < "$urls_file" | tr -d ' ')
    
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        count=$((count + 1))
        
        # Generate filename
        local filename
        filename=$(echo "$url" | md5sum | cut -d' ' -f1).png
        
        log_debug "[$count/$total] Capturing $url"
        
        if run_chrome_screenshot "$url" "$output_dir/$filename"; then
            echo "$url -> $filename" >> "$output_dir/screenshot_map.txt"
        fi
        
        # Rate limiting
        [ "${IS_WAF:-false}" = "true" ] && sleep 2 || sleep 0.5
        
    done < <(head -100 "$urls_file")  # Limit to 100 URLs
    
    log_info "Captured $count screenshots"
}

# ------------------------------------------------------------------------------
# organize_screenshots()
# Organize screenshots by status code and characteristics
# Arguments: $1 = Screenshots directory
# ------------------------------------------------------------------------------
organize_screenshots() {
    local screenshots_dir="$1"
    
    log_info "Organizing screenshots..."
    
    # Create category directories
    mkdir -p "$screenshots_dir/interesting"
    mkdir -p "$screenshots_dir/login_pages"
    mkdir -p "$screenshots_dir/error_pages"
    mkdir -p "$screenshots_dir/default_pages"
    
    # If gowitness report exists, parse it
    if [ -f "$screenshots_dir/gowitness.sqlite3" ]; then
        log_info "Gowitness report found - screenshots organized automatically"
        return 0
    fi
    
    # If aquatone report exists
    if [ -f "$screenshots_dir/aquatone_report.html" ]; then
        log_info "Aquatone report found"
        return 0
    fi
    
    log_info "Screenshots saved to: $screenshots_dir"
    return 0
}

# ------------------------------------------------------------------------------
# detect_interesting_pages()
# Detect login pages, admin panels, etc. from screenshots
# Arguments: $1 = Screenshots directory, $2 = URLs file
# ------------------------------------------------------------------------------
detect_interesting_pages() {
    local screenshots_dir="$1"
    local urls_file="$2"
    
    log_info "Detecting interesting pages..."
    
    local interesting_patterns=(
        "login"
        "signin"
        "sign-in"
        "admin"
        "dashboard"
        "portal"
        "panel"
        "console"
        "manager"
        "auth"
    )
    
    local interesting_file="$screenshots_dir/interesting_urls.txt"
    : > "$interesting_file"
    
    while IFS= read -r url; do
        for pattern in "${interesting_patterns[@]}"; do
            if echo "$url" | grep -qi "$pattern"; then
                echo "$url" >> "$interesting_file"
                break
            fi
        done
    done < "$urls_file"
    
    local count
    count=$(wc -l < "$interesting_file" 2>/dev/null | tr -d ' ' || echo 0)
    log_info "Found $count potentially interesting pages"
}

# ------------------------------------------------------------------------------
# generate_html_gallery()
# Generate HTML gallery of screenshots
# Arguments: $1 = Screenshots directory, $2 = Mapping file
# ------------------------------------------------------------------------------
generate_html_gallery() {
    local screenshots_dir="$1"
    local map_file="$screenshots_dir/screenshot_map.txt"
    local gallery_file="$screenshots_dir/gallery.html"
    
    if [ ! -f "$map_file" ]; then
        return 1
    fi
    
    log_info "Generating screenshot gallery..."
    
    cat > "$gallery_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>GHOST-FRAMEWORK Screenshot Gallery</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: #0d1117;
            color: #c9d1d9;
            margin: 0;
            padding: 20px;
        }
        h1 {
            color: #58a6ff;
            text-align: center;
            border-bottom: 2px solid #30363d;
            padding-bottom: 10px;
        }
        .gallery {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        .screenshot-card {
            background: #161b22;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }
        .screenshot-card img {
            width: 100%;
            height: 250px;
            object-fit: cover;
        }
        .screenshot-card .url {
            padding: 10px;
            font-size: 12px;
            word-break: break-all;
            color: #8b949e;
        }
        .screenshot-card:hover {
            transform: scale(1.02);
            transition: transform 0.2s;
        }
        a {
            color: #58a6ff;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <h1>🔍 GHOST-FRAMEWORK Screenshot Gallery</h1>
    <div class="gallery">
EOF

    while IFS=' -> ' read -r url filename; do
        [ -z "$url" ] || [ -z "$filename" ] && continue
        
        if [ -f "$screenshots_dir/$filename" ]; then
            cat >> "$gallery_file" << EOF
        <div class="screenshot-card">
            <a href="$filename" target="_blank">
                <img src="$filename" alt="$url">
            </a>
            <div class="url"><a href="$url" target="_blank">$url</a></div>
        </div>
EOF
        fi
    done < "$map_file"

    cat >> "$gallery_file" << 'EOF'
    </div>
</body>
</html>
EOF

    log_success "Gallery generated: $gallery_file"
}

# ------------------------------------------------------------------------------
# generate_screenshots_report()
# Generate screenshot summary report
# Arguments: $1 = Screenshots directory
# ------------------------------------------------------------------------------
generate_screenshots_report() {
    local screenshots_dir="$1"
    local report_file="$screenshots_dir/screenshots_summary.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Screenshot Report"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date)"
        echo ""
        
        local total_screenshots
        total_screenshots=$(find "$screenshots_dir" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
        echo "Total Screenshots: $total_screenshots"
        echo ""
        
        if [ -f "$screenshots_dir/interesting_urls.txt" ]; then
            echo "Interesting Pages:"
            cat "$screenshots_dir/interesting_urls.txt"
        fi
        
    } > "$report_file"
}

# ------------------------------------------------------------------------------
# run_screenshots()
# Main function to run screenshot capture
# Arguments: $1 = Workspace directory
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
run_screenshots() {
    local workspace="$1"
    
    print_section "Screenshot Capture"
    log_info "Workspace: $workspace"
    
    # Check if enabled
    if [ "${SCREENSHOTS_ENABLED:-true}" != "true" ]; then
        log_info "Screenshots disabled in config"
        return 0
    fi
    
    # Detect screenshot tool
    local tool
    tool=$(detect_screenshot_tool)
    
    if [ -z "$tool" ]; then
        log_warn "No screenshot tool available"
        log_info "Install gowitness: go install github.com/sensepost/gowitness@latest"
        return 1
    fi
    
    log_info "Using screenshot tool: $tool"
    
    # Get targets
    local targets_file="$workspace/live_hosts.txt"
    if [ ! -f "$targets_file" ] || [ ! -s "$targets_file" ]; then
        log_warn "No live hosts found"
        return 1
    fi
    
    # Create output directory
    local screenshots_dir="$workspace/screenshots"
    mkdir -p "$screenshots_dir"
    
    local target_count
    target_count=$(wc -l < "$targets_file" | tr -d ' ')
    log_info "Capturing screenshots for $target_count hosts..."
    
    # Run screenshot capture based on available tool
    case "$tool" in
        gowitness)
            run_gowitness "$targets_file" "$screenshots_dir"
            ;;
        aquatone)
            run_aquatone "$targets_file" "$screenshots_dir"
            ;;
        chrome|chromium)
            capture_with_chrome "$targets_file" "$screenshots_dir"
            ;;
    esac
    
    # Organize and analyze
    organize_screenshots "$screenshots_dir"
    detect_interesting_pages "$screenshots_dir" "$targets_file"
    
    # Generate gallery if using Chrome
    if [ "$tool" = "chrome" ] || [ "$tool" = "chromium" ]; then
        generate_html_gallery "$screenshots_dir"
    fi
    
    # Generate report
    generate_screenshots_report "$screenshots_dir"
    
    # Summary
    print_section "Screenshots Complete"
    
    local screenshot_count
    screenshot_count=$(find "$screenshots_dir" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    log_success "Captured $screenshot_count screenshots"
    
    if [ -f "$screenshots_dir/gallery.html" ]; then
        log_info "Gallery: $screenshots_dir/gallery.html"
    fi
    
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Screenshot Module"
    echo "Usage: source screenshots.sh && run_screenshots <workspace>"
fi
