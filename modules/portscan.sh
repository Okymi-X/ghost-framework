#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Port Scanning Module
# ==============================================================================
# File: modules/portscan.sh
# Description: Fast port scanning with service detection using naabu
# License: MIT
# Version: 1.1.0
#
# This module provides:
# - Fast SYN scanning with naabu
# - Service version detection
# - Automatic service-specific vulnerability scanning
# - WAF-aware (auto-disabled when WAF detected)
# ==============================================================================

# Common service ports
readonly TOP_PORTS_100="21,22,23,25,53,80,110,111,135,139,143,161,443,445,465,514,587,993,995,1025,1433,1521,1723,2049,2082,2083,2181,2222,2375,2376,2483,3000,3128,3306,3389,3690,4443,5000,5432,5672,5900,5984,6379,6443,6666,7001,7002,8000,8008,8009,8010,8020,8080,8081,8082,8083,8087,8088,8089,8090,8161,8181,8443,8444,8787,8880,8888,8983,9000,9001,9002,9042,9043,9090,9091,9100,9200,9300,9418,9443,9999,10000,10250,10443,11211,11300,15672,16379,19999,27017,27018,28017,50000,50070"

# Interesting ports for security
readonly SECURITY_PORTS="21,22,23,25,53,80,110,111,135,139,143,161,389,443,445,465,514,587,636,993,995,1433,1521,1723,3306,3389,5432,5900,5984,6379,8080,8443,9200,11211,27017"

# Port to service mapping
declare -A PORT_SERVICES=(
    [21]="FTP"
    [22]="SSH"
    [23]="Telnet"
    [25]="SMTP"
    [53]="DNS"
    [80]="HTTP"
    [110]="POP3"
    [111]="RPC"
    [135]="MSRPC"
    [139]="NetBIOS"
    [143]="IMAP"
    [161]="SNMP"
    [389]="LDAP"
    [443]="HTTPS"
    [445]="SMB"
    [465]="SMTPS"
    [514]="Syslog"
    [587]="SMTP"
    [636]="LDAPS"
    [993]="IMAPS"
    [995]="POP3S"
    [1433]="MSSQL"
    [1521]="Oracle"
    [1723]="PPTP"
    [2049]="NFS"
    [3306]="MySQL"
    [3389]="RDP"
    [5432]="PostgreSQL"
    [5672]="RabbitMQ"
    [5900]="VNC"
    [5984]="CouchDB"
    [6379]="Redis"
    [6443]="Kubernetes"
    [7001]="WebLogic"
    [8080]="HTTP-Proxy"
    [8443]="HTTPS-Alt"
    [9000]="SonarQube"
    [9200]="Elasticsearch"
    [9418]="Git"
    [10250]="Kubelet"
    [11211]="Memcached"
    [15672]="RabbitMQ-Mgmt"
    [27017]="MongoDB"
)

# Service-specific Nuclei tags
declare -A SERVICE_NUCLEI_TAGS=(
    [21]="ftp"
    [22]="ssh"
    [25]="smtp"
    [53]="dns"
    [80]="http"
    [110]="pop3"
    [139]="smb,netbios"
    [143]="imap"
    [161]="snmp"
    [389]="ldap"
    [443]="ssl,https"
    [445]="smb"
    [1433]="mssql"
    [1521]="oracle"
    [3306]="mysql"
    [3389]="rdp"
    [5432]="postgres"
    [5900]="vnc"
    [5984]="couchdb"
    [6379]="redis"
    [9200]="elasticsearch"
    [11211]="memcached"
    [27017]="mongodb"
)

# ------------------------------------------------------------------------------
# check_portscan_prerequisites()
# Check if port scanning tools are available
# Returns: 0 if ready, 1 if not
# ------------------------------------------------------------------------------
check_portscan_prerequisites() {
    if command -v naabu &>/dev/null; then
        return 0
    fi
    
    if command -v nmap &>/dev/null; then
        log_warn "naabu not found, falling back to nmap"
        return 0
    fi
    
    log_error "No port scanning tool available (naabu or nmap)"
    return 1
}

# ------------------------------------------------------------------------------
# run_naabu_scan()
# Run fast port scan with naabu
# Arguments: $1 = Hosts file, $2 = Output file, $3 = Ports (optional)
# ------------------------------------------------------------------------------
run_naabu_scan() {
    local hosts_file="$1"
    local output_file="$2"
    local ports="${3:-$TOP_PORTS_100}"
    
    if ! command -v naabu &>/dev/null; then
        log_warn "naabu not installed"
        return 1
    fi
    
    log_info "Running naabu port scan..."
    
    # Build command
    local naabu_opts="-silent"
    
    # Add ports
    naabu_opts="$naabu_opts -p $ports"
    
    # Rate limiting
    local rate="${PORTSCAN_RATE:-1000}"
    [ "${IS_WAF:-false}" = "true" ] && rate=$((rate / 4))
    naabu_opts="$naabu_opts -rate $rate"
    
    # Threads
    local threads="${PORTSCAN_THREADS:-25}"
    [ "${IS_WAF:-false}" = "true" ] && threads=$((threads / 2))
    naabu_opts="$naabu_opts -c $threads"
    
    # Execute
    naabu -l "$hosts_file" $naabu_opts -o "$output_file" 2>/dev/null
    
    return $?
}

# ------------------------------------------------------------------------------
# run_nmap_scan()
# Fallback to nmap if naabu not available
# Arguments: $1 = Hosts file, $2 = Output file, $3 = Ports (optional)
# ------------------------------------------------------------------------------
run_nmap_scan() {
    local hosts_file="$1"
    local output_file="$2"
    local ports="${3:-$TOP_PORTS_100}"
    
    if ! command -v nmap &>/dev/null; then
        log_error "nmap not installed"
        return 1
    fi
    
    log_info "Running nmap port scan..."
    
    # Rate limiting for WAF
    local timing="T4"
    [ "${IS_WAF:-false}" = "true" ] && timing="T2"
    
    nmap -iL "$hosts_file" -p "$ports" -$timing --open -oG "$output_file.gnmap" 2>/dev/null
    
    # Parse gnmap to simple format (host:port)
    grep "open" "$output_file.gnmap" 2>/dev/null | \
        awk '{
            host=$2;
            for(i=1;i<=NF;i++) {
                if ($i ~ /\/open/) {
                    split($i, a, "/");
                    print host ":" a[1]
                }
            }
        }' > "$output_file"
    
    return $?
}

# ------------------------------------------------------------------------------
# detect_service_version()
# Get service version for a specific port
# Arguments: $1 = Host, $2 = Port
# Returns: Service banner/version
# ------------------------------------------------------------------------------
detect_service_version() {
    local host="$1"
    local port="$2"
    
    # Try to grab banner
    local banner
    banner=$(echo "QUIT" | timeout 3 nc "$host" "$port" 2>/dev/null | head -1 | tr -d '\r\n')
    
    if [ -n "$banner" ]; then
        echo "$banner"
        return 0
    fi
    
    # Return service name if known
    if [ -n "${PORT_SERVICES[$port]:-}" ]; then
        echo "${PORT_SERVICES[$port]}"
    else
        echo "Unknown"
    fi
}

# ------------------------------------------------------------------------------
# categorize_ports()
# Categorize open ports by service type
# Arguments: $1 = Ports file, $2 = Output directory
# ------------------------------------------------------------------------------
categorize_ports() {
    local ports_file="$1"
    local output_dir="$2"
    
    log_info "Categorizing open ports..."
    
    # Create category files
    : > "$output_dir/web_services.txt"
    : > "$output_dir/database_services.txt"
    : > "$output_dir/admin_services.txt"
    : > "$output_dir/other_services.txt"
    
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        
        local host port
        host=$(echo "$entry" | cut -d: -f1)
        port=$(echo "$entry" | cut -d: -f2)
        
        case "$port" in
            80|443|8080|8443|8000|8888|3000|5000|9000)
                echo "$entry" >> "$output_dir/web_services.txt"
                ;;
            3306|5432|1433|1521|27017|6379|11211|5984|9200)
                echo "$entry" >> "$output_dir/database_services.txt"
                ;;
            22|23|3389|5900|10250|2222)
                echo "$entry" >> "$output_dir/admin_services.txt"
                ;;
            *)
                echo "$entry" >> "$output_dir/other_services.txt"
                ;;
        esac
        
    done < "$ports_file"
    
    # Report counts
    log_info "Web services: $(wc -l < "$output_dir/web_services.txt" | tr -d ' ')"
    log_info "Database services: $(wc -l < "$output_dir/database_services.txt" | tr -d ' ')"
    log_info "Admin services: $(wc -l < "$output_dir/admin_services.txt" | tr -d ' ')"
}

# ------------------------------------------------------------------------------
# scan_service_vulnerabilities()
# Run Nuclei with service-specific templates
# Arguments: $1 = Host:Port, $2 = Output file
# ------------------------------------------------------------------------------
scan_service_vulnerabilities() {
    local entry="$1"
    local output_file="$2"
    
    local host port
    host=$(echo "$entry" | cut -d: -f1)
    port=$(echo "$entry" | cut -d: -f2)
    
    # Get nuclei tags for this service
    local tags="${SERVICE_NUCLEI_TAGS[$port]:-}"
    
    if [ -z "$tags" ] || ! command -v nuclei &>/dev/null; then
        return
    fi
    
    # Run nuclei with specific tags
    echo "$host:$port" | nuclei -tags "$tags" -silent >> "$output_file" 2>/dev/null
}

# ------------------------------------------------------------------------------
# generate_portscan_report()
# Generate port scan summary report
# Arguments: $1 = Port scan directory
# ------------------------------------------------------------------------------
generate_portscan_report() {
    local portscan_dir="$1"
    local report_file="$portscan_dir/portscan_summary.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "        GHOST-FRAMEWORK - Port Scan Report"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Scan Date: $(date)"
        echo ""
        
        if [ -f "$portscan_dir/open_ports.txt" ]; then
            echo "Total Open Ports: $(wc -l < "$portscan_dir/open_ports.txt" | tr -d ' ')"
        fi
        
        echo ""
        echo "SERVICE BREAKDOWN:"
        echo "──────────────────"
        
        for category in web database admin other; do
            if [ -f "$portscan_dir/${category}_services.txt" ]; then
                local count
                count=$(wc -l < "$portscan_dir/${category}_services.txt" | tr -d ' ')
                printf "%-20s %s\n" "${category^}:" "$count"
            fi
        done
        
        echo ""
        echo "UNIQUE PORTS FOUND:"
        echo "───────────────────"
        if [ -f "$portscan_dir/open_ports.txt" ]; then
            cut -d: -f2 "$portscan_dir/open_ports.txt" | sort -n | uniq -c | sort -rn | head -20
        fi
        
    } > "$report_file"
}

# ------------------------------------------------------------------------------
# run_port_scan()
# Main function to run port scanning
# Arguments: $1 = Workspace directory
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
run_port_scan() {
    local workspace="$1"
    
    print_section "Port Scanning"
    log_info "Workspace: $workspace"
    
    # Check if enabled
    if [ "${PORTSCAN_ENABLED:-true}" != "true" ]; then
        log_info "Port scanning disabled in config"
        return 0
    fi
    
    # Check WAF status
    if [ "${IS_WAF:-false}" = "true" ] && [ "${WAF_DISABLE_PORTSCAN:-true}" = "true" ]; then
        log_warn "Port scanning disabled due to WAF detection"
        return 0
    fi
    
    # Check prerequisites
    if ! check_portscan_prerequisites; then
        return 1
    fi
    
    # Get hosts to scan
    local hosts_file="$workspace/resolved.txt"
    if [ ! -f "$hosts_file" ]; then
        hosts_file="$workspace/subdomains.txt"
    fi
    
    if [ ! -f "$hosts_file" ] || [ ! -s "$hosts_file" ]; then
        log_warn "No hosts file found"
        return 1
    fi
    
    # Create output directory
    local portscan_dir="$workspace/portscan"
    mkdir -p "$portscan_dir"
    
    local host_count
    host_count=$(wc -l < "$hosts_file" | tr -d ' ')
    log_info "Scanning $host_count hosts..."
    
    # Determine ports to scan
    local ports="${PORTSCAN_PORTS:-$TOP_PORTS_100}"
    if [ "${PORTSCAN_FULL:-false}" = "true" ]; then
        ports="1-65535"
        log_warn "Full port scan enabled - this will take a while"
    fi
    
    # Run port scan
    if command -v naabu &>/dev/null; then
        run_naabu_scan "$hosts_file" "$portscan_dir/open_ports.txt" "$ports"
    else
        run_nmap_scan "$hosts_file" "$portscan_dir/open_ports.txt" "$ports"
    fi
    
    # Check results
    if [ ! -f "$portscan_dir/open_ports.txt" ] || [ ! -s "$portscan_dir/open_ports.txt" ]; then
        log_info "No open ports found"
        return 0
    fi
    
    local port_count
    port_count=$(wc -l < "$portscan_dir/open_ports.txt" | tr -d ' ')
    log_success "Found $port_count open ports"
    
    # Categorize ports
    categorize_ports "$portscan_dir/open_ports.txt" "$portscan_dir"
    
    # Scan for service vulnerabilities
    log_info "Checking for service-specific vulnerabilities..."
    
    # Focus on high-value targets
    for service_file in "$portscan_dir/database_services.txt" "$portscan_dir/admin_services.txt"; do
        if [ -f "$service_file" ]; then
            while IFS= read -r entry; do
                scan_service_vulnerabilities "$entry" "$portscan_dir/service_vulns.txt"
            done < "$service_file"
        fi
    done
    
    # Generate report
    generate_portscan_report "$portscan_dir"
    
    # Summary
    print_section "Port Scan Complete"
    log_info "Open ports: $port_count"
    
    # Highlight interesting findings
    local db_count admin_count
    db_count=$(wc -l < "$portscan_dir/database_services.txt" 2>/dev/null | tr -d ' ' || echo 0)
    admin_count=$(wc -l < "$portscan_dir/admin_services.txt" 2>/dev/null | tr -d ' ' || echo 0)
    
    [ "$db_count" -gt 0 ] && log_warn "Database services exposed: $db_count"
    [ "$admin_count" -gt 0 ] && log_warn "Admin services exposed: $admin_count"
    
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Port Scanning Module"
    echo "Usage: source portscan.sh && run_port_scan <workspace>"
fi
