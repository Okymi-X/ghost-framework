# 👻 GHOST-FRAMEWORK

<div align="center">

![GHOST-FRAMEWORK Banner](https://img.shields.io/badge/GHOST--FRAMEWORK-v1.3.0-cyan?style=for-the-badge&logo=ghost)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Go](https://img.shields.io/badge/Go-1.21%2B-00ADD8.svg?style=flat-square&logo=go)](https://golang.org/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat-square)](https://github.com/Okymi-X/ghost-framework/issues)

**🔥 Ultimate Bug Bounty Automation Framework — 25 Scripts, 10,000+ Lines, 16 Scan Phases 🔥**

[Features](#-features) •
[Installation](#-installation) •
[Usage](#-usage) •
[📚 Documentation](docs/) •
[Contributing](#-contributing)

</div>

---

## 🎯 What is GHOST-FRAMEWORK?

GHOST-FRAMEWORK is an **open-source bug bounty automation framework** designed for security researchers and penetration testers. It automates the entire reconnaissance → crawling → vulnerability scanning pipeline while adapting to target defenses like WAFs and CDNs.

### Why GHOST?

| Feature | Description |
|---------|-------------|
| 🧩 **Modular** | 17 independent modules, add/remove without breaking |
| 🔧 **Auto-Healing** | Missing tools? Automatically installs them |
| 🛡️ **Stealth Mode** | Detects WAFs and adapts speed to avoid blocks |
| 📊 **Pro Reports** | MD, HTML, JSON, CSV + Executive Summary |
| 🔔 **Notifications** | Discord, Slack, Telegram real-time alerts |
| ⏸️ **Resume** | Save & resume interrupted scans |
| 🔌 **Proxy** | Burp Suite & OWASP ZAP integration |

---

## ✨ Features (30+)

<details>
<summary><b>🔍 Reconnaissance</b></summary>

- Subdomain enumeration (Subfinder, Amass, Assetfinder)
- DNS resolution (dnsx)
- HTTP probing (httpx)
- WAF/CDN detection (Cloudflare, Akamai, etc.)
- Technology fingerprinting
</details>

<details>
<summary><b>🕷️ Discovery</b></summary>

- URL crawling (Katana, GAU)
- Parameter extraction (GF patterns)
- JavaScript file discovery
- Directory fuzzing (ffuf)
- Port scanning (naabu)
- Cloud bucket scanning (S3, Azure, GCP)
</details>

<details>
<summary><b>🔐 Intelligence</b></summary>

- JavaScript secrets extraction (40+ patterns)
- GitHub dorking for leaks
- Email harvesting
- Wayback Machine analysis
- Custom wordlist generation
</details>

<details>
<summary><b>🎯 Vulnerability Scanning</b></summary>

- Nuclei template scanning
- XSS detection (Dalfox)
- SQL injection
- SSRF / Open Redirect
- CORS misconfiguration
- CRLF injection
- Subdomain takeover (40+ fingerprints)
- API fuzzing (IDOR, GraphQL, mass assignment)
</details>

<details>
<summary><b>📊 Reporting</b></summary>

- Markdown reports
- HTML dashboard
- JSON export
- CSV findings
- Executive summary
</details>

---

## 📦 Installation

```bash
# Clone
git clone https://github.com/Okymi-X/ghost-framework.git
cd ghost-framework

# Install (auto-installs Go + 20 tools)
chmod +x ghost.sh
./ghost.sh --install
```

> 📖 [Detailed installation guide](docs/USER_GUIDE.md#-installation)

---

## 🚀 Usage

### Basic Scan

```bash
./ghost.sh -d example.com
```

### Scan Modes

```bash
# Stealth (default) - Slow, quiet, evades WAF
./ghost.sh -d target.com -m stealth

# Aggressive - Fast, noisy, for authorized testing
./ghost.sh -d target.com -m aggressive
```

### Common Options

```bash
./ghost.sh -d target.com --recon-only      # Only reconnaissance
./ghost.sh -d target.com --skip-vuln       # Skip vulnerability scan
./ghost.sh -d target.com -o /path/output   # Custom output
./ghost.sh --resume /path/to/workspace     # Resume interrupted scan
./ghost.sh -d target.com --proxy 127.0.0.1:8080  # Through Burp
```

> 📖 [Complete usage guide](docs/USER_GUIDE.md#-usage-guide)

---

## 📁 Project Structure

```
ghost-framework/
├── ghost.sh                 # 🚀 Main CLI (837 lines)
├── config/
│   └── ghost.conf.example   # ⚙️ Configuration template
├── modules/                 # 📦 17 scan modules (7,388 lines)
│   ├── recon.sh             # Reconnaissance
│   ├── takeover.sh          # Subdomain takeover
│   ├── portscan.sh          # Port scanning
│   ├── crawling.sh          # URL crawling
│   ├── secrets.sh           # JS secrets
│   ├── fuzzing.sh           # Directory fuzzing
│   ├── screenshots.sh       # Screenshots
│   ├── cloud.sh             # Cloud buckets
│   ├── github.sh            # GitHub dorking
│   ├── techdetect.sh        # Tech detection
│   ├── wordlist.sh          # Wordlist generator
│   ├── wayback.sh           # Wayback analysis
│   ├── emails.sh            # Email harvesting
│   ├── apifuzz.sh           # API fuzzing
│   ├── templates.sh         # Nuclei template builder
│   ├── vulnerability.sh     # Vuln scanning
│   └── installer.sh         # Auto-installer
├── utils/                   # 🔧 7 utilities (2,108 lines)
│   ├── banner.sh            # Colors & ASCII art
│   ├── logger.sh            # Logging
│   ├── notifications.sh     # Webhooks
│   ├── proxy.sh             # Burp/ZAP support
│   ├── resume.sh            # Save/resume scans
│   ├── parallel.sh          # Job queue
│   └── reporter.sh          # Report generator
├── docs/                    # 📚 Documentation
│   ├── USER_GUIDE.md        # Complete user guide
│   ├── CONFIGURATION.md     # Config reference
│   ├── EXAMPLES.md          # Practical examples
│   └── DEVELOPMENT.md       # Module development
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [📖 User Guide](docs/USER_GUIDE.md) | Complete usage, installation, all features |
| [⚙️ Configuration](docs/CONFIGURATION.md) | All config options with defaults |
| [🎯 Examples](docs/EXAMPLES.md) | Practical workflows, integrations |
| [🔧 Development](docs/DEVELOPMENT.md) | Create your own modules |

---

## ⚙️ Configuration

```bash
# Copy and edit config
cp config/ghost.conf.example config/ghost.conf
nano config/ghost.conf
```

### Key Settings

```bash
# API Keys (optional but recommended)
GITHUB_TOKEN="your_token"
HUNTER_API_KEY="your_key"

# Notifications
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
TELEGRAM_BOT_TOKEN="your_bot_token"

# Module toggles
PORTSCAN_ENABLED="true"
FUZZING_ENABLED="true"
API_FUZZ_ENABLED="true"
```

> 📖 [Complete configuration reference](docs/CONFIGURATION.md)

---

## 📊 Output

```
results/example_com_2024-01-15/
├── subdomains.txt           # Discovered subdomains
├── live_hosts.txt           # Active web servers
├── all_urls.txt             # Crawled URLs
├── findings/                # Vulnerability results
│   ├── nuclei_results.json
│   └── xss_results.txt
├── secrets/                 # Extracted secrets
├── screenshots/             # Visual recon
├── GHOST_REPORT.md          # Markdown report
├── GHOST_REPORT.html        # HTML dashboard
├── GHOST_REPORT.json        # JSON export
├── findings.csv             # CSV export
└── EXECUTIVE_SUMMARY.md     # For management
```

---

## 🤝 Contributing

We welcome contributions! 

```bash
# Fork, clone, create branch
git checkout -b feature/awesome-feature

# Make changes, commit, push
git commit -m "Add awesome feature"
git push origin feature/awesome-feature

# Open Pull Request
```

> 📖 [Development guide](docs/DEVELOPMENT.md)

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🗺️ Roadmap

- [x] **v1.0** - ✅ Core framework
- [x] **v1.1** - ✅ Takeover, secrets, ports, fuzzing, screenshots
- [x] **v1.2** - ✅ Cloud, GitHub, tech, wordlists, Wayback, proxy
- [x] **v1.3** - ✅ Emails, API fuzz, resume, templates, parallel, reports
- [ ] **v1.4** - Scheduled scans, diff reports
- [ ] **v2.0** - Web UI dashboard

---

## 📊 Stats

| Metric | Value |
|--------|-------|
| Total Scripts | 25 |
| Lines of Code | 10,333+ |
| Modules | 17 |
| Utilities | 7 |
| Scan Phases | 16 |
| Documentation | 1,870 lines |

---

## ⚠️ Disclaimer

This tool is intended for **authorized security testing only**. Always obtain proper written authorization before scanning any systems. The developers are not responsible for any misuse.

---

## 📜 License

MIT License - See [LICENSE](LICENSE)

---

<div align="center">

**Made with ❤️ by [Okymi-X](https://github.com/Okymi-X)**

⭐ Star this repo if you find it useful!

[Report Bug](https://github.com/Okymi-X/ghost-framework/issues) •
[Request Feature](https://github.com/Okymi-X/ghost-framework/issues)

</div>
