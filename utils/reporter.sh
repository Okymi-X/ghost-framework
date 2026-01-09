#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Advanced Report Generator
# ==============================================================================
# File: utils/reporter.sh
# Description: Generate professional reports in multiple formats
# License: MIT
# Version: 1.3.0
# ==============================================================================

# Report templates
readonly REPORT_FORMATS=("markdown" "html" "json" "csv")

# ------------------------------------------------------------------------------
# generate_json_report()
# Generate comprehensive JSON report
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
generate_json_report() {
    local workspace="$1"
    local output_file="$workspace/GHOST_REPORT.json"
    
    log_info "Generating JSON report..."
    
    local subdomains=0 live_hosts=0 urls=0 vulns=0
    [ -f "$workspace/subdomains.txt" ] && subdomains=$(wc -l < "$workspace/subdomains.txt" | tr -d ' ')
    [ -f "$workspace/live_hosts.txt" ] && live_hosts=$(wc -l < "$workspace/live_hosts.txt" | tr -d ' ')
    [ -f "$workspace/all_urls.txt" ] && urls=$(wc -l < "$workspace/all_urls.txt" | tr -d ' ')
    [ -d "$workspace/findings" ] && vulns=$(cat "$workspace/findings"/*.txt 2>/dev/null | wc -l | tr -d ' ')
    
    cat > "$output_file" << EOF
{
    "report": {
        "title": "GHOST-FRAMEWORK Security Assessment",
        "version": "${GHOST_VERSION:-1.3.0}",
        "generated_at": "$(date -Iseconds)",
        "target": "${TARGET_DOMAIN:-unknown}"
    },
    "summary": {
        "subdomains": $subdomains,
        "live_hosts": $live_hosts,
        "urls_crawled": $urls,
        "total_findings": $vulns,
        "waf_detected": ${IS_WAF:-false},
        "waf_provider": "${WAF_PROVIDER:-null}"
    },
    "findings": {
        "critical": ${FINDING_COUNTS[critical]:-0},
        "high": ${FINDING_COUNTS[high]:-0},
        "medium": ${FINDING_COUNTS[medium]:-0},
        "low": ${FINDING_COUNTS[low]:-0},
        "info": ${FINDING_COUNTS[info]:-0}
    },
    "phases_completed": [
        $([ "${PHASE_RECON_COMPLETE:-false}" = "true" ] && echo '"recon",' || true)
        $([ "${PHASE_CRAWL_COMPLETE:-false}" = "true" ] && echo '"crawl",' || true)
        $([ "${PHASE_VULN_COMPLETE:-false}" = "true" ] && echo '"vulnerability"' || true)
    ],
    "files": {
        "subdomains": "subdomains.txt",
        "live_hosts": "live_hosts.txt",
        "urls": "all_urls.txt",
        "findings": "findings/"
    }
}
EOF
    
    log_success "JSON report: $output_file"
}

# ------------------------------------------------------------------------------
# generate_csv_findings()
# Export findings as CSV
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
generate_csv_findings() {
    local workspace="$1"
    local output_file="$workspace/findings.csv"
    
    log_info "Generating CSV findings export..."
    
    echo "Severity,Type,URL,Description,Source" > "$output_file"
    
    # Parse Nuclei JSON if available
    if [ -f "$workspace/findings/nuclei_results.json" ] && command -v jq &>/dev/null; then
        jq -r '.[] | [.info.severity, .info.name, .matched, .info.description // "N/A", "nuclei"] | @csv' \
            "$workspace/findings/nuclei_results.json" 2>/dev/null >> "$output_file"
    fi
    
    # Add other findings
    for file in "$workspace/findings"/*.txt; do
        [ -f "$file" ] || continue
        local source
        source=$(basename "$file" .txt)
        
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            echo "info,$source,\"$line\",\"Finding from $source\",\"$source\"" >> "$output_file"
        done < "$file"
    done
    
    log_success "CSV export: $output_file"
}

# ------------------------------------------------------------------------------
# generate_executive_summary()
# Generate executive summary for non-technical audience
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
generate_executive_summary() {
    local workspace="$1"
    local output_file="$workspace/EXECUTIVE_SUMMARY.md"
    
    log_info "Generating executive summary..."
    
    local critical=${FINDING_COUNTS[critical]:-0}
    local high=${FINDING_COUNTS[high]:-0}
    local medium=${FINDING_COUNTS[medium]:-0}
    local low=${FINDING_COUNTS[low]:-0}
    local total=$((critical + high + medium + low))
    
    local risk_level="LOW"
    [ "$low" -gt 5 ] && risk_level="MEDIUM"
    [ "$medium" -gt 3 ] && risk_level="MEDIUM"
    [ "$high" -gt 0 ] && risk_level="HIGH"
    [ "$critical" -gt 0 ] && risk_level="CRITICAL"
    
    cat > "$output_file" << EOF
# Executive Summary - Security Assessment

**Target:** ${TARGET_DOMAIN:-Unknown}  
**Date:** $(date '+%Y-%m-%d')  
**Overall Risk Level:** **${risk_level}**

---

## Key Findings

| Severity | Count | Action Required |
|----------|-------|-----------------|
| 🔴 Critical | $critical | Immediate |
| 🟠 High | $high | Within 24 hours |
| 🟡 Medium | $medium | Within 7 days |
| 🔵 Low | $low | Within 30 days |

**Total Issues:** $total

---

## Attack Surface Analysis

EOF

    # Add statistics
    [ -f "$workspace/subdomains.txt" ] && \
        echo "- **Subdomains Discovered:** $(wc -l < "$workspace/subdomains.txt" | tr -d ' ')" >> "$output_file"
    
    [ -f "$workspace/live_hosts.txt" ] && \
        echo "- **Active Web Services:** $(wc -l < "$workspace/live_hosts.txt" | tr -d ' ')" >> "$output_file"
    
    [ -f "$workspace/all_urls.txt" ] && \
        echo "- **Endpoints Identified:** $(wc -l < "$workspace/all_urls.txt" | tr -d ' ')" >> "$output_file"
    
    # WAF Status
    cat >> "$output_file" << EOF

---

## Security Controls Detected

- **Web Application Firewall:** ${IS_WAF:-Not Detected}
$([ "${IS_WAF:-false}" = "true" ] && echo "- **WAF Provider:** ${WAF_PROVIDER:-Unknown}")

---

## Recommendations

1. **Immediate Actions** - Address all critical and high severity findings
2. **Short-term** - Review and remediate medium severity issues
3. **Long-term** - Establish continuous security monitoring

---

*Generated by GHOST-FRAMEWORK v${GHOST_VERSION:-1.3.0}*
EOF

    log_success "Executive summary: $output_file"
}

# ------------------------------------------------------------------------------
# generate_html_report()
# Generate professional HTML report
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
generate_html_report() {
    local workspace="$1"
    local output_file="$workspace/GHOST_REPORT.html"
    
    log_info "Generating HTML report..."
    
    local critical=${FINDING_COUNTS[critical]:-0}
    local high=${FINDING_COUNTS[high]:-0}
    local medium=${FINDING_COUNTS[medium]:-0}
    local low=${FINDING_COUNTS[low]:-0}
    
    cat > "$output_file" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GHOST-FRAMEWORK Security Report</title>
    <style>
        :root {
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --accent: #58a6ff;
            --critical: #f85149;
            --high: #db6d28;
            --medium: #d29922;
            --low: #3fb950;
            --info: #58a6ff;
        }
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', -apple-system, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        header {
            background: linear-gradient(135deg, var(--bg-secondary), var(--bg-tertiary));
            padding: 40px;
            border-radius: 12px;
            margin-bottom: 30px;
            border: 1px solid #30363d;
        }
        
        h1 {
            font-size: 2.5em;
            background: linear-gradient(90deg, var(--accent), #79c0ff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        
        .meta { color: var(--text-secondary); }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .card {
            background: var(--bg-secondary);
            border-radius: 12px;
            padding: 25px;
            border: 1px solid #30363d;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 30px rgba(0,0,0,0.3);
        }
        
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label { color: var(--text-secondary); }
        
        .critical .stat-value { color: var(--critical); }
        .high .stat-value { color: var(--high); }
        .medium .stat-value { color: var(--medium); }
        .low .stat-value { color: var(--low); }
        .info .stat-value { color: var(--info); }
        
        .section {
            background: var(--bg-secondary);
            border-radius: 12px;
            padding: 25px;
            margin-bottom: 20px;
            border: 1px solid #30363d;
        }
        
        .section h2 {
            color: var(--accent);
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #30363d;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #30363d;
        }
        
        th { color: var(--text-secondary); }
        
        .badge {
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 500;
        }
        
        .badge-critical { background: var(--critical); color: white; }
        .badge-high { background: var(--high); color: white; }
        .badge-medium { background: var(--medium); color: black; }
        .badge-low { background: var(--low); color: black; }
        
        footer {
            text-align: center;
            padding: 30px;
            color: var(--text-secondary);
            border-top: 1px solid #30363d;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>👻 GHOST-FRAMEWORK</h1>
            <p class="meta">Security Assessment Report</p>
HTMLEOF

    # Add dynamic content
    cat >> "$output_file" << EOF
            <p class="meta">Target: <strong>${TARGET_DOMAIN:-Unknown}</strong> | Date: $(date '+%Y-%m-%d %H:%M')</p>
        </header>
        
        <div class="grid">
            <div class="card critical">
                <div class="stat-value">$critical</div>
                <div class="stat-label">Critical</div>
            </div>
            <div class="card high">
                <div class="stat-value">$high</div>
                <div class="stat-label">High</div>
            </div>
            <div class="card medium">
                <div class="stat-value">$medium</div>
                <div class="stat-label">Medium</div>
            </div>
            <div class="card low">
                <div class="stat-value">$low</div>
                <div class="stat-label">Low</div>
            </div>
        </div>
        
        <div class="section">
            <h2>📊 Attack Surface</h2>
            <table>
                <tr><th>Metric</th><th>Count</th></tr>
EOF

    [ -f "$workspace/subdomains.txt" ] && \
        echo "<tr><td>Subdomains</td><td>$(wc -l < "$workspace/subdomains.txt" | tr -d ' ')</td></tr>" >> "$output_file"
    
    [ -f "$workspace/live_hosts.txt" ] && \
        echo "<tr><td>Live Hosts</td><td>$(wc -l < "$workspace/live_hosts.txt" | tr -d ' ')</td></tr>" >> "$output_file"
    
    [ -f "$workspace/all_urls.txt" ] && \
        echo "<tr><td>URLs Crawled</td><td>$(wc -l < "$workspace/all_urls.txt" | tr -d ' ')</td></tr>" >> "$output_file"
    
    echo "<tr><td>WAF Detected</td><td>${IS_WAF:-No}</td></tr>" >> "$output_file"
    
    cat >> "$output_file" << 'HTMLEOF'
            </table>
        </div>
        
        <footer>
            <p>Generated by GHOST-FRAMEWORK | https://github.com/Okymi-X/ghost-framework</p>
        </footer>
    </div>
</body>
</html>
HTMLEOF

    log_success "HTML report: $output_file"
}

# ------------------------------------------------------------------------------
# run_report_generator()
# Generate all report formats
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
run_report_generator() {
    local workspace="$1"
    
    print_section "Report Generator"
    
    generate_json_report "$workspace"
    generate_csv_findings "$workspace"
    generate_executive_summary "$workspace"
    generate_html_report "$workspace"
    
    log_success "All reports generated in $workspace"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Report Generator"
    echo "Usage: source reporter.sh && run_report_generator <workspace>"
fi
