# 📚 GHOST-FRAMEWORK Documentation

> Complete documentation for GHOST-FRAMEWORK v1.3.0 "Shadow"

---

## 📖 Documentation Index

| Document | Description |
|----------|-------------|
| [**User Guide**](USER_GUIDE.md) | Complete usage guide, installation, and features |
| [**Configuration**](CONFIGURATION.md) | All configuration options reference |
| [**Examples**](EXAMPLES.md) | Practical workflows and use cases |
| [**Development**](DEVELOPMENT.md) | Module development guide for contributors |

---

## 🚀 Quick Links

### Getting Started

```bash
# Install
git clone https://github.com/Okymi-X/ghost-framework.git
cd ghost-framework && chmod +x ghost.sh

# First run (installs dependencies)
./ghost.sh --install

# Your first scan
./ghost.sh -d example.com
```

### Common Commands

```bash
./ghost.sh -d target.com                    # Standard scan
./ghost.sh -d target.com -m aggressive      # Fast scan
./ghost.sh -d target.com --recon-only       # Recon only
./ghost.sh --resume /path/to/workspace      # Resume scan
```

---

## 📊 Framework Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    GHOST-FRAMEWORK v1.3.0                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Recon     │  │   Crawl     │  │   Vulnerability     │  │
│  │ • Subdomain │  │ • URLs      │  │ • Nuclei            │  │
│  │ • DNS       │  │ • Params    │  │ • XSS / SQLi        │  │
│  │ • WAF       │  │ • JS Files  │  │ • SSRF / CORS       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Discovery  │  │   Intel     │  │     Analysis        │  │
│  │ • Ports     │  │ • Secrets   │  │ • Tech Detect       │  │
│  │ • Dirs      │  │ • Emails    │  │ • Wayback           │  │
│  │ • Cloud     │  │ • GitHub    │  │ • Templates         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                     Reports                           │  │
│  │  Markdown • HTML • JSON • CSV • Executive Summary     │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
ghost-framework/
├── ghost.sh                 # Main CLI entry point
├── config/
│   └── ghost.conf.example   # Configuration template
├── modules/                 # 17 scan modules
│   ├── recon.sh
│   ├── crawling.sh
│   ├── vulnerability.sh
│   └── ...
├── utils/                   # 7 utility modules
│   ├── logger.sh
│   ├── notifications.sh
│   └── ...
├── docs/                    # Documentation
│   ├── USER_GUIDE.md
│   ├── CONFIGURATION.md
│   ├── EXAMPLES.md
│   └── DEVELOPMENT.md
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

---

## 🔗 External Resources

- **GitHub:** [github.com/Okymi-X/ghost-framework](https://github.com/Okymi-X/ghost-framework)
- **Issues:** [Report bugs](https://github.com/Okymi-X/ghost-framework/issues)
- **Discussions:** [Community](https://github.com/Okymi-X/ghost-framework/discussions)

---

## 📜 Version History

| Version | Codename | Highlights |
|---------|----------|------------|
| 1.0.0 | Phantom | Initial release |
| 1.1.0 | Phantom | Subdomain takeover, secrets, ports, fuzzing |
| 1.2.0 | Spectre | Cloud, GitHub, tech detect, Wayback |
| **1.3.0** | **Shadow** | Emails, API fuzz, resume, templates, reports |

---

<div align="center">

**Made with ❤️ by [Okymi-X](https://github.com/Okymi-X)**

</div>
