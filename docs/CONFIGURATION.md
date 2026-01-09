# ⚙️ GHOST-FRAMEWORK - Configuration Reference

> Complete reference for all configuration options

---

## Configuration File Location

```bash
config/ghost.conf         # Active configuration (gitignored)
config/ghost.conf.example # Template file
```

### Setup

```bash
cp config/ghost.conf.example config/ghost.conf
nano config/ghost.conf
```

---

## 📋 Complete Configuration Reference

### General Settings

| Option | Default | Description |
|--------|---------|-------------|
| `DEBUG` | `false` | Enable debug output |
| `VERBOSE` | `false` | Verbose logging |
| `RESULTS_DIR` | `./results` | Output directory |
| `KEEP_TEMP_FILES` | `false` | Keep temp files after scan |

```bash
DEBUG="false"
VERBOSE="false"
RESULTS_DIR="./results"
KEEP_TEMP_FILES="false"
```

---

### Scan Mode Settings

#### Stealth Mode (Default)

| Option | Default | Description |
|--------|---------|-------------|
| `STEALTH_THREADS` | `2` | Concurrent threads |
| `STEALTH_RATE_LIMIT` | `10` | Requests per second |
| `STEALTH_DELAY` | `2` | Delay between requests (seconds) |
| `STEALTH_TIMEOUT` | `30` | Request timeout (seconds) |

```bash
STEALTH_THREADS="2"
STEALTH_RATE_LIMIT="10"
STEALTH_DELAY="2"
STEALTH_TIMEOUT="30"
```

#### Aggressive Mode

| Option | Default | Description |
|--------|---------|-------------|
| `AGGRESSIVE_THREADS` | `50` | Concurrent threads |
| `AGGRESSIVE_RATE_LIMIT` | `150` | Requests per second |
| `AGGRESSIVE_DELAY` | `0` | No delay |
| `AGGRESSIVE_TIMEOUT` | `10` | Request timeout (seconds) |

```bash
AGGRESSIVE_THREADS="50"
AGGRESSIVE_RATE_LIMIT="150"
AGGRESSIVE_DELAY="0"
AGGRESSIVE_TIMEOUT="10"
```

---

### WAF Detection & Adaptation

| Option | Default | Description |
|--------|---------|-------------|
| `WAF_DETECTION_ENABLED` | `true` | Enable WAF detection |
| `WAF_REDUCE_THREADS` | `true` | Reduce threads when WAF detected |
| `WAF_THREAD_REDUCTION` | `4` | Divide threads by this factor |
| `WAF_DISABLE_PORTSCAN` | `true` | Disable port scanning for WAF targets |

```bash
WAF_DETECTION_ENABLED="true"
WAF_REDUCE_THREADS="true"
WAF_THREAD_REDUCTION="4"
WAF_DISABLE_PORTSCAN="true"
```

---

### API Keys

| Option | Description | Get Key |
|--------|-------------|---------|
| `SHODAN_API_KEY` | Shodan API | [shodan.io](https://shodan.io) |
| `SECURITYTRAILS_API_KEY` | SecurityTrails | [securitytrails.com](https://securitytrails.com) |
| `CHAOS_API_KEY` | ProjectDiscovery Chaos | [chaos.projectdiscovery.io](https://chaos.projectdiscovery.io) |
| `VIRUSTOTAL_API_KEY` | VirusTotal | [virustotal.com](https://virustotal.com) |
| `CENSYS_API_ID` | Censys | [censys.io](https://censys.io) |
| `CENSYS_API_SECRET` | Censys | [censys.io](https://censys.io) |
| `GITHUB_TOKEN` | GitHub dorking | [github.com/settings/tokens](https://github.com/settings/tokens) |
| `HUNTER_API_KEY` | Email harvesting | [hunter.io](https://hunter.io) |

```bash
SHODAN_API_KEY=""
SECURITYTRAILS_API_KEY=""
CHAOS_API_KEY=""
VIRUSTOTAL_API_KEY=""
CENSYS_API_ID=""
CENSYS_API_SECRET=""
GITHUB_TOKEN=""
HUNTER_API_KEY=""
```

---

### Notification Webhooks

#### Discord

```bash
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/ID/TOKEN"
```

#### Slack

```bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/XXX"
```

#### Telegram

```bash
TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
TELEGRAM_CHAT_ID="123456789"
```

#### Notification Settings

| Option | Default | Description |
|--------|---------|-------------|
| `NOTIFY_ON_CRITICAL` | `true` | Alert on critical findings |
| `NOTIFY_ON_HIGH` | `true` | Alert on high findings |
| `NOTIFY_ON_MEDIUM` | `false` | Alert on medium findings |
| `NOTIFY_ON_SCAN_COMPLETE` | `true` | Alert when scan completes |
| `NOTIFY_RATE_LIMIT` | `5` | Min seconds between notifications |

```bash
NOTIFY_ON_CRITICAL="true"
NOTIFY_ON_HIGH="true"
NOTIFY_ON_MEDIUM="false"
NOTIFY_ON_SCAN_COMPLETE="true"
NOTIFY_RATE_LIMIT="5"
```

---

### Wordlist Paths

| Option | Default Path |
|--------|--------------|
| `DNS_WORDLIST` | `/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt` |
| `WEB_WORDLIST` | `/usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt` |
| `PARAMS_WORDLIST` | `/usr/share/wordlists/seclists/Discovery/Web-Content/burp-parameter-names.txt` |

```bash
DNS_WORDLIST="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
WEB_WORDLIST="/usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt"
PARAMS_WORDLIST="/usr/share/wordlists/seclists/Discovery/Web-Content/burp-parameter-names.txt"
```

---

### Tool-Specific Settings

#### Subfinder

```bash
SUBFINDER_THREADS="10"
SUBFINDER_TIMEOUT="30"
SUBFINDER_ALL_SOURCES="true"
```

#### httpx

```bash
HTTPX_THREADS="50"
HTTPX_TIMEOUT="10"
HTTPX_RETRIES="2"
```

#### Nuclei

```bash
NUCLEI_THREADS="25"
NUCLEI_RATE_LIMIT="150"
NUCLEI_BULK_SIZE="25"
NUCLEI_SEVERITY="low,medium,high,critical"
NUCLEI_EXCLUDE_TAGS="dos,fuzz"
NUCLEI_TEMPLATES_UPDATE="true"
```

#### Katana

```bash
KATANA_THREADS="10"
KATANA_DEPTH="2"
KATANA_JS_CRAWL="true"
```

#### GAU

```bash
GAU_THREADS="5"
GAU_FETCH_SUBS="true"
GAU_PROVIDERS="wayback,commoncrawl,otx,urlscan"
```

#### Dalfox

```bash
DALFOX_THREADS="10"
DALFOX_TIMEOUT="10"
DALFOX_WAF_EVASION="true"
```

---

### Module Enable/Disable

| Option | Default | Module |
|--------|---------|--------|
| `SECRETS_SCAN_ENABLED` | `true` | JavaScript secrets |
| `TAKEOVER_ENABLED` | `true` | Subdomain takeover |
| `PORTSCAN_ENABLED` | `true` | Port scanning |
| `PORTSCAN_FULL` | `false` | Scan all 65535 ports |
| `FUZZING_ENABLED` | `true` | Directory fuzzing |
| `SCREENSHOTS_ENABLED` | `true` | Screenshot capture |
| `CLOUD_SCAN_ENABLED` | `true` | Cloud bucket scan |
| `GITHUB_DORK_ENABLED` | `true` | GitHub dorking |
| `TECH_DETECTION_ENABLED` | `true` | Tech fingerprinting |
| `WORDLIST_GENERATOR_ENABLED` | `true` | Custom wordlists |
| `WAYBACK_ENABLED` | `true` | Wayback analysis |
| `EMAIL_HARVEST_ENABLED` | `true` | Email harvesting |
| `API_FUZZ_ENABLED` | `true` | API fuzzing |
| `TEMPLATE_BUILDER_ENABLED` | `true` | Nuclei templates |

```bash
# Example: Minimal scan
SECRETS_SCAN_ENABLED="true"
TAKEOVER_ENABLED="true"
PORTSCAN_ENABLED="false"
FUZZING_ENABLED="false"
SCREENSHOTS_ENABLED="false"
CLOUD_SCAN_ENABLED="false"
GITHUB_DORK_ENABLED="false"
EMAIL_HARVEST_ENABLED="false"
API_FUZZ_ENABLED="false"
```

---

### Port Scanning Options

```bash
PORTSCAN_THREADS="25"
PORTSCAN_RATE="1000"
PORTSCAN_FULL="false"           # Set true for 1-65535
PORTSCAN_PORTS=""               # Custom ports, e.g., "80,443,8080"
```

---

### Parallel Execution

```bash
PARALLEL_JOBS="5"               # Max concurrent jobs
PARALLEL_TIMEOUT="300"          # Job timeout in seconds
```

---

### Proxy Settings

```bash
PROXY_ENABLED="false"
PROXY_HOST="127.0.0.1"
PROXY_PORT="8080"

# Burp Suite
BURP_HOST="127.0.0.1"
BURP_PORT="8080"

# OWASP ZAP
ZAP_HOST="127.0.0.1"
ZAP_PORT="8090"
ZAP_API_KEY=""
```

---

## 📁 Environment Variables

These can be set at runtime:

```bash
# Override config settings
TARGET_DOMAIN="example.com" ./ghost.sh -d example.com
THREADS="5" ./ghost.sh -d example.com
PROXY_ENABLED="true" ./ghost.sh -d example.com

# Or export
export GITHUB_TOKEN="your_token"
export HUNTER_API_KEY="your_key"
./ghost.sh -d example.com
```

---

## 🔒 Security Notes

1. **Never commit `ghost.conf` with API keys** - It's in `.gitignore`
2. **Use environment variables for CI/CD** - More secure than files
3. **Rotate API keys periodically** - Good security practice
4. **Limit GitHub token scope** - Read-only public repos is enough

---

<div align="center">

**Configure wisely! ⚙️**

</div>
