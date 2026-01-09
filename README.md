# 👻 GHOST-FRAMEWORK

<div align="center">

![GHOST-FRAMEWORK Banner](https://img.shields.io/badge/GHOST--FRAMEWORK-v1.3.0-cyan?style=for-the-badge&logo=ghost)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Go](https://img.shields.io/badge/Go-1.21%2B-00ADD8.svg?style=flat-square&logo=go)](https://golang.org/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat-square)](https://github.com/Okymi-X/ghost-framework/issues)

**A comprehensive, modular, and community-driven Bug Bounty Automation Framework**

[Features](#-features) •
[Installation](#-installation) •
[Usage](#-usage) •
[Modules](#-modules) •
[Configuration](#-configuration) •
[Contributing](#-contributing)

</div>

---

## 🎯 What is GHOST-FRAMEWORK?

GHOST-FRAMEWORK is an **open-source bug bounty automation framework** designed for security researchers and penetration testers. It automates the reconnaissance → crawling → vulnerability scanning pipeline while adapting to target defenses like WAFs and CDNs.

### Why GHOST?

- **🧩 Modular Architecture** - Each function is isolated in its own module. Add, remove, or modify components without breaking the system.
- **🔧 Auto-Healing** - Missing dependencies? GHOST automatically detects and installs them.
- **🛡️ Stealth Mode** - Automatically detects WAFs/CDNs and adapts scanning behavior to avoid detection.
- **📊 Professional Reports** - Generates clean Markdown and HTML reports of your findings.
- **🔔 Real-time Notifications** - Discord, Slack, and Telegram integration for instant alerts on critical findings.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Subdomain Enumeration** | Multi-source subdomain discovery with Subfinder + Amass |
| **DNS Resolution** | Fast DNS resolution with dnsx to filter live hosts |
| **WAF Detection** | Automatic detection of Cloudflare, Akamai, Incapsula, and more |
| **Adaptive Scanning** | Reduce threads and rate limits when WAF is detected |
| **🆕 Subdomain Takeover** | Detect vulnerable subdomains (40+ service fingerprints) |
| **🆕 Port Scanning** | Fast port scanning with naabu + service detection |
| **URL Crawling** | Historical (GAU) and live (Katana) URL discovery |
| **Parameter Mining** | Extract and classify parameters using GF patterns |
| **🆕 Secrets Extraction** | Extract API keys and tokens from JavaScript (40+ patterns) |
| **🆕 Directory Fuzzing** | Fast directory brute-forcing with ffuf |
| **🆕 Screenshots** | Visual reconnaissance with gowitness/aquatone |
| **Nuclei Scanning** | Template-based vulnerability scanning |
| **XSS Detection** | Dalfox integration for reflected XSS |
| **SQLi Detection** | SQL injection pattern detection |
| **🆕 SSRF Detection** | Server-Side Request Forgery checks |
| **🆕 CORS Check** | CORS misconfiguration detection |
| **🆕 Open Redirect** | Open redirect vulnerability detection |
| **🆕 CRLF Injection** | Header injection detection |
| **🆕 Cloud Buckets** | S3/Azure/GCP exposed bucket detection |
| **🆕 GitHub Dorking** | Search GitHub for leaked secrets |
| **🆕 Tech Detection** | CMS, framework, and WAF fingerprinting |
| **🆕 Wordlist Gen** | Custom target-specific wordlists |
| **🆕 Wayback Diff** | Find hidden/deleted endpoints |
| **🆕 Proxy Support** | Burp Suite & OWASP ZAP integration |
| **🆕 Email Harvest** | Extract emails from targets |
| **🆕 API Fuzzing** | REST/GraphQL with IDOR, mass assignment |
| **🆕 Resume Scans** | Save & resume interrupted scans |
| **🆕 Template Builder** | Generate custom Nuclei templates |
| **🆕 Parallel Jobs** | Multi-threaded job execution |
| **Report Generation** | Markdown + HTML + JSON + CSV reports |
| **Notifications** | Discord, Slack, Telegram webhooks |

---

## 📦 Installation

### Prerequisites

- Linux/macOS (WSL2 works on Windows)
- Bash 4.0+
- curl, git, jq

### Quick Install

```bash
# Clone the repository
git clone https://github.com/Okymi-X/ghost-framework.git
cd ghost-framework

# Make the main script executable
chmod +x ghost.sh

# Run the installer (installs Go and all tools)
./ghost.sh --install
```

### Manual Installation

If you prefer to install dependencies manually:

```bash
# Install Go (1.21+)
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin:~/go/bin

# Install tools
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/gf@latest
go install github.com/hahwul/dalfox/v2@latest
```

---

## 🚀 Usage

### Basic Scan

```bash
# Scan a domain with default (stealth) mode
./ghost.sh -d example.com

# Scan with aggressive mode (faster, noisier)
./ghost.sh -d example.com -m aggressive
```

### Advanced Options

```bash
# Skip certain phases
./ghost.sh -d example.com --skip-vuln         # Skip vulnerability scanning
./ghost.sh -d example.com --recon-only        # Only run reconnaissance

# Custom output directory
./ghost.sh -d example.com -o /path/to/output

# Enable debug mode
./ghost.sh -d example.com --debug

# Test notification webhooks
./ghost.sh --test-notify
```

### Full Options

```
Usage: ./ghost.sh [OPTIONS]

Required:
  -d, --domain DOMAIN     Target domain to scan

Optional:
  -m, --mode MODE         Scan mode: stealth (default) or aggressive
  -o, --output DIR        Output directory
  -c, --config FILE       Custom config file path

Scan Control:
  --skip-install          Skip dependency check
  --skip-recon            Skip reconnaissance phase
  --skip-crawl            Skip crawling phase
  --skip-vuln             Skip vulnerability scanning
  --recon-only            Run only reconnaissance
  --vuln-only             Run only vulnerability scan

Other:
  -v, --verbose           Enable verbose output
  --debug                 Enable debug mode
  -h, --help              Show help message
  --version               Show version information
  --install               Run the dependency installer
  --test-notify           Test notification webhooks
```

---

## 📁 Project Structure

```
ghost-framework/
├── ghost.sh              # 🚀 Main entry point (CLI wrapper)
├── config/
│   └── ghost.conf        # ⚙️ Configuration (API keys, threads, wordlists)
├── modules/
│   ├── installer.sh      # 📦 Dependency installer (18+ tools)
│   ├── recon.sh          # 🔍 Reconnaissance (subdomains, WAF detection)
│   ├── takeover.sh       # 🎯 Subdomain takeover detection
│   ├── portscan.sh       # 🔌 Port scanning with naabu
│   ├── crawling.sh       # 🕷️ URL crawling and parameter mining
│   ├── secrets.sh        # 🔐 JavaScript secrets extraction
│   ├── fuzzing.sh        # 🔍 Directory fuzzing with ffuf
│   ├── screenshots.sh    # 📸 Visual reconnaissance
│   ├── cloud.sh          # ☁️ Cloud bucket scanner
│   ├── github.sh         # 🐙 GitHub dorking
│   ├── techdetect.sh     # 🔬 Technology fingerprinting
│   ├── wordlist.sh       # 📝 Custom wordlist generator
│   ├── wayback.sh        # ⏳ Wayback Machine analysis
│   └── vulnerability.sh  # 🎯 Vulnerability scanning (10+ checks)
├── utils/
│   ├── banner.sh         # 🎨 ASCII art and colors
│   ├── logger.sh         # 📝 Logging functions
│   ├── notifications.sh  # 🔔 Webhook integrations
│   └── proxy.sh          # 🔌 Burp/ZAP proxy support
├── results/              # 📊 Scan results (auto-created)
├── README.md
├── CONTRIBUTING.md
└── .gitignore
```

---

## 🔧 Modules

### 🔍 Reconnaissance (`recon.sh`)

- Subdomain enumeration via Subfinder
- DNS resolution with dnsx
- HTTP probing with httpx
- **WAF/CDN Detection**: Automatically detects Cloudflare, Akamai, Incapsula, CloudFront, Sucuri, and more
- Sets `IS_WAF=true` flag and adapts scanning parameters

### 🕷️ Crawling (`crawling.sh`)

- Historical URL discovery with GAU (Wayback Machine, Common Crawl)
- Live crawling with Katana (including JavaScript parsing)
- Static asset filtering
- Parameter extraction with GF patterns (XSS, SQLi, SSRF, etc.)

### 🎯 Vulnerability Scanning (`vulnerability.sh`)

- Nuclei template scanning with WAF-aware rate limiting
- Dalfox XSS detection
- SQL injection pattern detection
- Finding deduplication and severity classification

### 📦 Installer (`installer.sh`)

- Auto-detects package manager (apt, yum, dnf, pacman, brew)
- Installs Go if missing
- Installs all required Go tools
- Updates Nuclei templates
- Installs GF patterns

---

## ⚙️ Configuration

Edit `config/ghost.conf` to customize:

```bash
# Scan Modes
STEALTH_THREADS="2"
STEALTH_RATE_LIMIT="10"
AGGRESSIVE_THREADS="50"
AGGRESSIVE_RATE_LIMIT="150"

# WAF Behavior
WAF_DETECTION_ENABLED="true"
WAF_REDUCE_THREADS="true"
WAF_DISABLE_PORTSCAN="true"

# API Keys (for enhanced results)
SHODAN_API_KEY=""
SECURITYTRAILS_API_KEY=""
CHAOS_API_KEY=""

# Notifications
DISCORD_WEBHOOK_URL=""
SLACK_WEBHOOK_URL=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
```

> ⚠️ **Important**: Never commit `ghost.conf` with API keys to public repositories!

---

## 📊 Output

GHOST-FRAMEWORK generates organized output in timestamped directories:

```
results/example_com_2024-01-15_14-30-00/
├── subdomains.txt        # Discovered subdomains
├── live_hosts.txt        # Live web servers
├── all_urls.txt          # All crawled URLs
├── js_files.txt          # JavaScript files
├── params/
│   ├── urls_with_params.txt
│   ├── xss_params.txt    # GF XSS patterns
│   ├── sqli_params.txt   # GF SQLi patterns
│   └── ...
├── findings/
│   ├── nuclei_results.txt
│   ├── nuclei_results.json
│   ├── xss_results.txt
│   └── sqli_results.txt
├── GHOST_REPORT.md       # Markdown report
└── GHOST_REPORT.html     # HTML report
```

---

## 🤝 Contributing

We love contributions! GHOST-FRAMEWORK is built for the community, by the community.

### Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest features
- 📝 Improve documentation
- 🔧 Submit pull requests
- ⭐ Star the repository

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Quick Start for Contributors

```bash
# Fork the repo, then:
git clone https://github.com/YOUR_USERNAME/ghost-framework.git
cd ghost-framework
git checkout -b feature/my-awesome-feature

# Make your changes, then:
git commit -m "Add awesome feature"
git push origin feature/my-awesome-feature
```

---

## 🗺️ Roadmap

- [x] **v1.1** - ✅ Subdomain takeover, secrets, ports, fuzzing, screenshots
- [x] **v1.2** - ✅ Cloud buckets, GitHub dorking, tech detection, wordlists, Wayback
- [x] **v1.3** - ✅ Email harvest, API fuzzing, resume scans, template builder
- [x] **v1.3** - ✅ Parallel execution, advanced reporting (JSON/CSV/HTML)
- [ ] **v1.4** - Scheduled scans & diff reports
- [ ] **v2.0** - Web UI dashboard

---

## ⚠️ Disclaimer

This tool is intended for **authorized security testing only**. Always obtain proper written authorization before scanning any systems. The developers are not responsible for any misuse or damage caused by this tool.

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🌟 Support

If you find GHOST-FRAMEWORK useful, please consider:

- ⭐ **Starring** this repository
- 🐦 **Sharing** on social media
- 💬 **Joining** our community discussions

---

<div align="center">

**Made with ❤️ by the Security Community**

[Report Bug](https://github.com/Okymi-X/ghost-framework/issues) •
[Request Feature](https://github.com/Okymi-X/ghost-framework/issues) •

</div>
