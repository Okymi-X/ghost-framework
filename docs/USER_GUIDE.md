# 📚 GHOST-FRAMEWORK Documentation

> **Version 1.3.0 "Shadow"** | Complete Bug Bounty Automation Framework

---

## Table of Contents

1. [Quick Start](#-quick-start)
2. [Installation](#-installation)
3. [Configuration](#-configuration)
4. [Usage Guide](#-usage-guide)
5. [Scan Phases](#-scan-phases)
6. [Module Reference](#-module-reference)
7. [Advanced Features](#-advanced-features)
8. [Output & Reports](#-output--reports)
9. [Troubleshooting](#-troubleshooting)
10. [API Reference](#-api-reference)

---

## 🚀 Quick Start

```bash
# Clone and install
git clone https://github.com/Okymi-X/ghost-framework.git
cd ghost-framework
chmod +x ghost.sh
./ghost.sh --install

# Run your first scan
./ghost.sh -d example.com
```

That's it! GHOST will automatically:
- Install all dependencies
- Enumerate subdomains
- Detect WAF/CDN
- Crawl URLs
- Find vulnerabilities
- Generate reports

---

## 📦 Installation

### Prerequisites

| Requirement | Minimum Version |
|-------------|-----------------|
| OS | Linux / macOS / WSL2 |
| Bash | 4.0+ |
| Go | 1.21+ (auto-installed) |
| curl, git, jq | Latest |
| Root access | Recommended for nmap |

### One-Line Install

```bash
git clone https://github.com/Okymi-X/ghost-framework.git && cd ghost-framework && chmod +x ghost.sh && ./ghost.sh --install
```

### Manual Tool Installation

If the auto-installer fails, install tools manually:

```bash
# Go tools
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install github.com/ffuf/ffuf/v2@latest
go install github.com/sensepost/gowitness@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/gf@latest
go install github.com/hahwul/dalfox/v2@latest

# System tools
sudo apt install -y curl git jq nmap chromium
```

---

## ⚙️ Configuration

### Config File Location

```
config/ghost.conf         # Main configuration
config/ghost.conf.example # Template (copy and customize)
```

### Essential Settings

```bash
# Copy example config
cp config/ghost.conf.example config/ghost.conf

# Edit configuration
nano config/ghost.conf
```

### Configuration Options

#### Scan Modes

```bash
# Stealth Mode (slow, quiet - evades detection)
STEALTH_THREADS="2"
STEALTH_RATE_LIMIT="10"
STEALTH_DELAY="2"

# Aggressive Mode (fast, noisy - for authorized tests)
AGGRESSIVE_THREADS="50"
AGGRESSIVE_RATE_LIMIT="150"
AGGRESSIVE_DELAY="0"
```

#### API Keys (Optional but Recommended)

```bash
# Enhanced subdomain enumeration
SHODAN_API_KEY="your_key"
SECURITYTRAILS_API_KEY="your_key"
CHAOS_API_KEY="your_key"

# GitHub dorking
GITHUB_TOKEN="your_token"

# Email harvesting
HUNTER_API_KEY="your_key"
```

#### Notifications

```bash
# Discord
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."

# Slack
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."

# Telegram
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"
```

#### Module Toggles

```bash
# Enable/disable specific modules
PORTSCAN_ENABLED="true"
FUZZING_ENABLED="true"
SCREENSHOTS_ENABLED="true"
SECRETS_SCAN_ENABLED="true"
TAKEOVER_ENABLED="true"
CLOUD_SCAN_ENABLED="true"
GITHUB_DORK_ENABLED="true"
EMAIL_HARVEST_ENABLED="true"
API_FUZZ_ENABLED="true"
TEMPLATE_BUILDER_ENABLED="true"
```

---

## 🎯 Usage Guide

### Basic Commands

```bash
# Standard scan (stealth mode)
./ghost.sh -d target.com

# Aggressive scan (faster but noisier)
./ghost.sh -d target.com -m aggressive

# Custom output directory
./ghost.sh -d target.com -o /path/to/output

# Custom config file
./ghost.sh -d target.com -c /path/to/config.conf
```

### Scan Control Options

```bash
# Skip specific phases
./ghost.sh -d target.com --skip-recon      # Skip subdomain enumeration
./ghost.sh -d target.com --skip-crawl      # Skip URL crawling
./ghost.sh -d target.com --skip-vuln       # Skip vulnerability scanning

# Run only specific phases
./ghost.sh -d target.com --recon-only      # Only reconnaissance
./ghost.sh -d target.com --vuln-only       # Only vulnerability scan
```

### Advanced Options

```bash
# Enable debug mode (verbose output)
./ghost.sh -d target.com --debug

# Skip dependency check
./ghost.sh -d target.com --skip-install

# Test notification webhooks
./ghost.sh --test-notify

# Resume interrupted scan
./ghost.sh --resume /path/to/workspace

# Connect to proxy (Burp/ZAP)
./ghost.sh -d target.com --proxy 127.0.0.1:8080
```

### Full Command Reference

```
Usage: ./ghost.sh [OPTIONS]

Required:
  -d, --domain DOMAIN     Target domain to scan

Optional:
  -m, --mode MODE         Scan mode: stealth (default) or aggressive
  -o, --output DIR        Output directory
  -c, --config FILE       Custom config file

Scan Control:
  --skip-install          Skip dependency check
  --skip-recon            Skip reconnaissance phase
  --skip-crawl            Skip crawling phase
  --skip-vuln             Skip vulnerability scanning
  --recon-only            Run only reconnaissance
  --vuln-only             Run only vulnerability scan

Advanced:
  --resume PATH           Resume interrupted scan
  --proxy HOST:PORT       Route through proxy
  -v, --verbose           Verbose output
  --debug                 Debug mode

Other:
  --install               Install dependencies
  --test-notify           Test webhooks
  --version               Show version
  -h, --help              Show help
```

---

## 🔄 Scan Phases

GHOST-FRAMEWORK executes 16 automated phases:

| Phase | Module | Description |
|-------|--------|-------------|
| 1 | **Recon** | Subdomain enumeration, DNS resolution, WAF detection |
| 2 | **Takeover** | Subdomain takeover vulnerability check |
| 3 | **Portscan** | Port scanning with service detection |
| 4 | **Crawling** | URL discovery, parameter extraction |
| 5 | **Secrets** | JavaScript secrets extraction |
| 6 | **Fuzzing** | Directory brute-forcing |
| 7 | **Screenshots** | Visual reconnaissance |
| 8 | **Cloud** | S3/Azure/GCP bucket scanning |
| 9 | **GitHub** | GitHub dorking for leaks |
| 10 | **Tech** | Technology fingerprinting |
| 11 | **Wordlist** | Custom wordlist generation |
| 12 | **Wayback** | Historical endpoint analysis |
| 13 | **Emails** | Email harvesting |
| 14 | **API Fuzz** | REST/GraphQL API testing |
| 15 | **Vuln** | Nuclei + Dalfox vulnerability scan |
| 16 | **Templates** | Generate custom Nuclei templates |

### WAF-Aware Scanning

When a WAF is detected, GHOST automatically:
- Reduces threads by 75%
- Adds delays between requests
- Lowers rate limits
- Disables aggressive scans

---

## 📦 Module Reference

### Reconnaissance (`modules/recon.sh`)

**Purpose:** Discover attack surface

```bash
# Functions available
run_recon <domain> <workspace>
run_subdomain_enum <domain> <output_file>
run_dns_resolution <subdomains_file> <output_file>
run_http_probe <dns_file> <output_file>
detect_waf <hosts_file>
```

**Output Files:**
- `subdomains.txt` - All discovered subdomains
- `resolved.txt` - DNS-resolved hosts
- `live_hosts.txt` - Responding HTTP servers
- `waf_detected.txt` - WAF indicators

---

### Subdomain Takeover (`modules/takeover.sh`)

**Purpose:** Detect vulnerable subdomains  
**Supports:** 40+ services (AWS S3, Azure, GitHub Pages, Heroku, etc.)

**Output:**
- `takeover_vulnerable.txt` - Confirmed vulnerabilities
- `takeover_potential.txt` - Requires manual verification

---

### Port Scanning (`modules/portscan.sh`)

**Purpose:** Identify open ports and services

**Default Ports:** Top 100 most common  
**Full Scan:** `PORTSCAN_FULL="true"` for all 65535 ports

**Output:**
- `open_ports.txt` - Open ports per host
- `web_services.txt` - HTTP/HTTPS services
- `database_services.txt` - Database ports
- `admin_services.txt` - SSH, RDP, etc.

---

### URL Crawling (`modules/crawling.sh`)

**Purpose:** Discover endpoints and parameters

**Sources:**
- Wayback Machine
- Common Crawl
- Live crawling with Katana

**Output:**
- `all_urls.txt` - All discovered URLs
- `js_files.txt` - JavaScript files
- `params/` - Categorized parameters (XSS, SQLi, SSRF, etc.)

---

### Secrets Extraction (`modules/secrets.sh`)

**Purpose:** Find exposed credentials in JavaScript

**Detects 40+ patterns:**
- AWS Keys, Google API Keys
- Stripe, Twilio, SendGrid tokens
- JWT secrets, Private keys
- Database connection strings

**Output:**
- `secrets/js_secrets.txt` - Extracted secrets
- `secrets/critical_secrets.txt` - High-priority findings

---

### Directory Fuzzing (`modules/fuzzing.sh`)

**Purpose:** Discover hidden files and directories

**Features:**
- ffuf integration
- Sensitive file checks (.env, .git, wp-config)
- Admin panel detection
- Backup file discovery

**Output:**
- `directories.txt` - Discovered paths
- `sensitive_files.txt` - Exposed configs
- `admin_panels.txt` - Admin interfaces

---

### Cloud Bucket (`modules/cloud.sh`)

**Purpose:** Find misconfigured cloud storage

**Providers:**
- AWS S3
- Azure Blob Storage
- Google Cloud Storage
- DigitalOcean Spaces

**Output:**
- `vulnerable_buckets.txt` - Exposed buckets
- `bruteforce_results.txt` - Discovered names

---

### API Fuzzing (`modules/apifuzz.sh`)

**Purpose:** Test REST/GraphQL APIs

**Tests:**
- IDOR (Insecure Direct Object Reference)
- Mass Assignment
- GraphQL Introspection
- Method Override

**Output:**
- `api/vulnerabilities.txt` - Findings
- `api/swagger_*.json` - Exposed documentation

---

### Email Harvesting (`modules/emails.sh`)

**Purpose:** Collect employee emails

**Sources:**
- Website scraping
- Hunter.io API
- Phonebook.cz

**Output:**
- `emails/target_emails.txt` - Domain emails
- `emails/email_report.txt` - Analysis

---

## 🔧 Advanced Features

### Resume Interrupted Scans

```bash
# Scan gets interrupted
./ghost.sh -d target.com
# (Ctrl+C or system crash)

# Resume from where it stopped
./ghost.sh --resume results/target_com_2024-01-15_14-30-00/
```

### Proxy Integration

```bash
# Route through Burp Suite
./ghost.sh -d target.com --proxy 127.0.0.1:8080

# Route through OWASP ZAP
./ghost.sh -d target.com --proxy 127.0.0.1:8090
```

### Custom Nuclei Templates

GHOST automatically generates templates from findings:

```bash
# Templates saved to
~/.nuclei-templates/custom-ghost/

# Run with custom templates
nuclei -l targets.txt -t ~/.nuclei-templates/custom-ghost/
```

### Parallel Execution

```bash
# Configure in ghost.conf
PARALLEL_JOBS="10"
```

---

## 📊 Output & Reports

### Directory Structure

```
results/target_com_2024-01-15_14-30-00/
├── subdomains.txt           # Discovered subdomains
├── live_hosts.txt           # Active web servers
├── all_urls.txt             # Crawled URLs
├── js_files.txt             # JavaScript files
├── waf_info.txt             # WAF detection results
│
├── recon/                   # Reconnaissance data
├── crawl/                   # Crawling results
├── params/                  # Extracted parameters
│   ├── xss_params.txt
│   ├── sqli_params.txt
│   └── ssrf_params.txt
│
├── findings/                # Vulnerability results
│   ├── nuclei_results.txt
│   ├── nuclei_results.json
│   ├── xss_results.txt
│   └── sqli_results.txt
│
├── secrets/                 # Extracted secrets
├── screenshots/             # Captured screenshots
├── cloud/                   # Cloud bucket results
├── api/                     # API fuzzing results
├── emails/                  # Harvested emails
│
├── GHOST_REPORT.md          # Markdown report
├── GHOST_REPORT.html        # HTML report
├── GHOST_REPORT.json        # JSON export
├── findings.csv             # CSV export
├── EXECUTIVE_SUMMARY.md     # Business summary
└── ghost.log                # Scan log
```

### Report Formats

| Format | Use Case |
|--------|----------|
| **Markdown** | Technical documentation |
| **HTML** | Shareable web report |
| **JSON** | API/Integration |
| **CSV** | Spreadsheet analysis |
| **Executive** | Management summary |

---

## 🔧 Troubleshooting

### Common Issues

#### "Command not found: subfinder"

```bash
# Ensure Go bin is in PATH
export PATH=$PATH:~/go/bin

# Or run installer
./ghost.sh --install
```

#### "Permission denied"

```bash
# Make executable
chmod +x ghost.sh
chmod +x modules/*.sh
chmod +x utils/*.sh
```

#### "naabu requires root"

```bash
# Run with sudo for SYN scanning
sudo ./ghost.sh -d target.com
```

#### WAF Blocking Requests

```bash
# Use stealth mode (default)
./ghost.sh -d target.com -m stealth

# Reduce config values
STEALTH_THREADS="1"
STEALTH_RATE_LIMIT="5"
STEALTH_DELAY="5"
```

### Debug Mode

```bash
# Enable verbose output
./ghost.sh -d target.com --debug

# Check logs
tail -f results/*/ghost.log
```

---

## 📖 API Reference

### Environment Variables

```bash
TARGET_DOMAIN      # Current target
WORKSPACE          # Output directory
IS_WAF             # WAF detected (true/false)
WAF_PROVIDER       # Detected WAF name
SCAN_MODE          # stealth/aggressive
THREADS            # Current thread count
RATE_LIMIT         # Current rate limit
```

### Sourcing Modules

```bash
# Use modules in your scripts
source /path/to/ghost-framework/modules/recon.sh
source /path/to/ghost-framework/utils/logger.sh

# Initialize
init_logger "/tmp/my_scan.log"

# Use functions
run_subdomain_enum "example.com" "/tmp/subs.txt"
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Missing argument |
| 130 | Interrupted (Ctrl+C) |

---

## 📜 License

MIT License - See [LICENSE](../LICENSE)

---

## 🤝 Support

- **Issues:** [GitHub Issues](https://github.com/Okymi-X/ghost-framework/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Okymi-X/ghost-framework/discussions)

---

<div align="center">

**Made with ❤️ by [Okymi-X](https://github.com/Okymi-X)**

</div>
