# Changelog

All notable changes to GHOST-FRAMEWORK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Scheduled scans with cron
- Diff reports between scans
- Web UI dashboard

---

## [1.3.0] - 2026-01-09 "Shadow"

### Added
- **Email Harvesting** (`modules/emails.sh`) - Extract emails from websites, Hunter.io, Phonebook
- **API Fuzzing** (`modules/apifuzz.sh`) - REST/GraphQL testing with IDOR, mass assignment, introspection
- **Nuclei Template Builder** (`modules/templates.sh`) - Auto-generate templates from findings
- **Diff Scanner** (`modules/diff.sh`) - Compare scans over time
- **Resume Capability** (`utils/resume.sh`) - Save and resume interrupted scans
- **Parallel Executor** (`utils/parallel.sh`) - Job queue for multi-threaded execution
- **Rate Limiter** (`utils/ratelimit.sh`) - Adaptive rate limiting
- **Scheduler** (`utils/scheduler.sh`) - Cron-based scan scheduling
- **Advanced Reporter** (`utils/reporter.sh`) - JSON, CSV, HTML, Executive Summary reports
- **Comprehensive Documentation** - 1,870 lines across 5 docs files
- **GitHub CI/CD** - Automated syntax checking and security scanning
- **Issue Templates** - Bug reports and feature requests
- **Security Policy** - Vulnerability disclosure guidelines

### Changed
- Scan pipeline expanded to 16 phases
- Total codebase now 10,955+ lines
- Updated README with professional formatting

---

## [1.2.0] - 2026-01-09 "Spectre"

### Added
- **Cloud Bucket Scanner** (`modules/cloud.sh`) - S3, Azure, GCP bucket detection
- **GitHub Dorking** (`modules/github.sh`) - Search GitHub for leaked secrets
- **Technology Detection** (`modules/techdetect.sh`) - CMS, framework, WAF fingerprinting
- **Wordlist Generator** (`modules/wordlist.sh`) - Custom target-specific wordlists
- **Wayback Analysis** (`modules/wayback.sh`) - Historical endpoint discovery
- **Proxy Support** (`utils/proxy.sh`) - Burp Suite & OWASP ZAP integration

### Changed
- Scan pipeline expanded to 13 phases
- Added 6 new tools to installer

---

## [1.1.0] - 2026-01-09 "Phantom"

### Added
- **Secrets Extraction** (`modules/secrets.sh`) - 40+ regex patterns for JS secrets
- **Subdomain Takeover** (`modules/takeover.sh`) - 40+ vulnerable service fingerprints
- **Port Scanning** (`modules/portscan.sh`) - naabu/nmap with service detection
- **Directory Fuzzing** (`modules/fuzzing.sh`) - ffuf with sensitive file checks
- **Screenshot Capture** (`modules/screenshots.sh`) - gowitness/aquatone integration
- **Enhanced Vulnerability Scans** - SSRF, CORS, Open Redirect, CRLF, Header checks

### Changed
- Added amass, assetfinder, naabu, ffuf, gowitness, subjack to installer
- Scan pipeline expanded to 8 phases

---

## [1.0.0] - 2026-01-09 "Phantom"

### Added
- Initial release
- **Reconnaissance** (`modules/recon.sh`) - Subdomain enumeration, DNS, WAF detection
- **Crawling** (`modules/crawling.sh`) - URL discovery, parameter extraction
- **Vulnerability Scanning** (`modules/vulnerability.sh`) - Nuclei, Dalfox, SQLi
- **Installer** (`modules/installer.sh`) - Auto-install Go and tools
- **Logger** (`utils/logger.sh`) - Timestamped logging
- **Notifications** (`utils/notifications.sh`) - Discord, Slack, Telegram
- **Banner** (`utils/banner.sh`) - Colored output

---

## Version History

| Version | Codename | Release Date | Highlights |
|---------|----------|--------------|------------|
| 1.3.0 | Shadow | 2026-01-09 | Emails, API fuzz, resume, templates, diff |
| 1.2.0 | Spectre | 2026-01-09 | Cloud, GitHub, tech, Wayback |
| 1.1.0 | Phantom | 2026-01-09 | Takeover, secrets, ports, fuzzing |
| 1.0.0 | Phantom | 2026-01-09 | Initial release |

---

[Unreleased]: https://github.com/Okymi-X/ghost-framework/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/Okymi-X/ghost-framework/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Okymi-X/ghost-framework/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Okymi-X/ghost-framework/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Okymi-X/ghost-framework/releases/tag/v1.0.0
