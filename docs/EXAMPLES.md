# 🎯 GHOST-FRAMEWORK - Examples & Use Cases

> Exemples pratiques pour différents scénarios de bug bounty

---

## 📋 Table of Contents

1. [Basic Scans](#basic-scans)
2. [Bug Bounty Workflows](#bug-bounty-workflows)
3. [Stealth Operations](#stealth-operations)
4. [Continuous Monitoring](#continuous-monitoring)
5. [Integration Examples](#integration-examples)

---

## Basic Scans

### Quick Reconnaissance Only

```bash
# Fast subdomain discovery without vulnerability scanning
./ghost.sh -d target.com --recon-only

# Output: subdomains.txt, live_hosts.txt
```

### Full Aggressive Scan

```bash
# Complete scan with maximum speed (authorized testing only)
./ghost.sh -d target.com -m aggressive

# All 16 phases executed at full speed
```

### Focused API Testing

```bash
# Disable other modules, focus on APIs
export API_FUZZ_ENABLED="true"
export PORTSCAN_ENABLED="false"
export SCREENSHOTS_ENABLED="false"
export EMAIL_HARVEST_ENABLED="false"

./ghost.sh -d api.target.com
```

---

## Bug Bounty Workflows

### 1. New Program Reconnaissance

```bash
#!/bin/bash
# new_program.sh - Initial recon for new bug bounty program

DOMAIN="$1"
DATE=$(date +%Y%m%d)

# Create program directory
mkdir -p ~/bugbounty/$DOMAIN

# Run comprehensive recon
cd /path/to/ghost-framework
./ghost.sh -d "$DOMAIN" -o ~/bugbounty/$DOMAIN/$DATE -m stealth

# Generate target list for manual testing
cat ~/bugbounty/$DOMAIN/$DATE/live_hosts.txt | sort -u > ~/bugbounty/$DOMAIN/targets.txt

echo "Recon complete! Check ~/bugbounty/$DOMAIN/$DATE/"
```

### 2. Subdomain Takeover Hunt

```bash
#!/bin/bash
# takeover_hunt.sh - Focus on subdomain takeovers

DOMAIN="$1"

# Disable most modules, focus on takeover
export TAKEOVER_ENABLED="true"
export PORTSCAN_ENABLED="false"
export FUZZING_ENABLED="false"
export SCREENSHOTS_ENABLED="false"
export VULN_SCAN_ENABLED="false"

./ghost.sh -d "$DOMAIN" --skip-crawl --skip-vuln

# Check results
cat results/*/takeover/takeover_vulnerable.txt 2>/dev/null
```

### 3. JavaScript Secrets Hunt

```bash
#!/bin/bash
# js_secrets.sh - Hunt for secrets in JavaScript

DOMAIN="$1"

# Focus on JS analysis
export SECRETS_SCAN_ENABLED="true"
export PORTSCAN_ENABLED="false"
export FUZZING_ENABLED="false"
export EMAIL_HARVEST_ENABLED="false"

./ghost.sh -d "$DOMAIN"

# Extract high-value findings
grep -iE "(api|key|secret|token|password)" \
    results/*/secrets/js_secrets.txt 2>/dev/null
```

### 4. Multiple Targets Batch Scan

```bash
#!/bin/bash
# batch_scan.sh - Scan multiple domains

TARGETS="domains.txt"

while IFS= read -r domain; do
    echo "[*] Scanning: $domain"
    ./ghost.sh -d "$domain" -m stealth
    
    # Wait between targets (respect rate limits)
    sleep 300
done < "$TARGETS"
```

---

## Stealth Operations

### Maximum Stealth Mode

```bash
# ghost.conf settings
STEALTH_THREADS="1"
STEALTH_RATE_LIMIT="5"
STEALTH_DELAY="5"
STEALTH_TIMEOUT="60"

# Disable noisy modules
PORTSCAN_ENABLED="false"
FUZZING_ENABLED="false"
API_FUZZ_ENABLED="false"

# Run
./ghost.sh -d target.com -m stealth
```

### Through Proxy/VPN

```bash
# Route through Burp Suite
./ghost.sh -d target.com --proxy 127.0.0.1:8080

# Or set environment proxy
export http_proxy="socks5://127.0.0.1:9050"  # Tor
export https_proxy="socks5://127.0.0.1:9050"
./ghost.sh -d target.com
```

### Resume After Detection

```bash
# If WAF blocks you, wait and resume
./ghost.sh -d target.com

# (Get blocked)
# Wait 1 hour...

# Resume with extra stealth
STEALTH_DELAY="10" ./ghost.sh --resume results/target_com_*/
```

---

## Continuous Monitoring

### Daily Recon Script

```bash
#!/bin/bash
# daily_recon.sh - Run daily via cron

DOMAIN="$1"
NOTIFY_WEBHOOK="https://discord.com/api/webhooks/..."
BASEDIR="$HOME/monitoring/$DOMAIN"

# Today's scan
TODAY=$(date +%Y%m%d)
./ghost.sh -d "$DOMAIN" -o "$BASEDIR/$TODAY" --skip-vuln

# Compare with yesterday
YESTERDAY=$(date -d "yesterday" +%Y%m%d)

if [ -f "$BASEDIR/$YESTERDAY/subdomains.txt" ]; then
    # Find new subdomains
    NEW=$(comm -23 \
        <(sort "$BASEDIR/$TODAY/subdomains.txt") \
        <(sort "$BASEDIR/$YESTERDAY/subdomains.txt"))
    
    if [ -n "$NEW" ]; then
        # Alert on new subdomains
        curl -X POST "$NOTIFY_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"🆕 New subdomains for $DOMAIN:\\n\`\`\`$NEW\`\`\`\"}"
    fi
fi
```

### Cron Setup

```bash
# Edit crontab
crontab -e

# Add daily scan at 3 AM
0 3 * * * /path/to/daily_recon.sh target.com >> /var/log/ghost_cron.log 2>&1
```

---

## Integration Examples

### With Burp Suite

```bash
# 1. Start Burp Suite with proxy on 8080

# 2. Run GHOST through Burp
./ghost.sh -d target.com --proxy 127.0.0.1:8080

# 3. All requests appear in Burp's HTTP History
# 4. Use Burp's Scanner on discovered endpoints
```

### With Nuclei Custom Templates

```bash
# 1. Run GHOST to generate templates
./ghost.sh -d target.com

# 2. Templates auto-generated in
ls ~/.nuclei-templates/custom-ghost/

# 3. Run Nuclei with custom + default templates
nuclei -l results/*/live_hosts.txt \
    -t ~/.nuclei-templates/custom-ghost/ \
    -t ~/nuclei-templates/
```

### Export to Other Tools

```bash
# Export to Burp/ZAP scope
cat results/*/live_hosts.txt | \
    sed 's|https\?://||' | \
    cut -d/ -f1 | \
    sort -u > scope.txt

# Export for Nmap
cat results/*/subdomains.txt | \
    xargs -I {} host {} | \
    grep "has address" | \
    awk '{print $4}' | \
    sort -u > ips.txt

nmap -iL ips.txt -sV -oA nmap_results

# Export URLs for SQLMap
grep -E "\?.*=" results/*/all_urls.txt > sqli_targets.txt
```

### Python Integration

```python
#!/usr/bin/env python3
# ghost_wrapper.py - Python wrapper for GHOST

import subprocess
import json
import os

def run_ghost_scan(domain, output_dir=None, mode="stealth"):
    """Run GHOST-FRAMEWORK scan and return results."""
    
    cmd = ["./ghost.sh", "-d", domain, "-m", mode]
    
    if output_dir:
        cmd.extend(["-o", output_dir])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        raise Exception(f"Scan failed: {result.stderr}")
    
    # Find latest results
    results_dir = output_dir or find_latest_results(domain)
    
    return {
        "subdomains": read_file(f"{results_dir}/subdomains.txt"),
        "live_hosts": read_file(f"{results_dir}/live_hosts.txt"),
        "findings": read_json(f"{results_dir}/GHOST_REPORT.json"),
    }

def read_file(path):
    if os.path.exists(path):
        with open(path) as f:
            return f.read().strip().split("\n")
    return []

def read_json(path):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {}

# Usage
if __name__ == "__main__":
    results = run_ghost_scan("example.com")
    print(f"Found {len(results['subdomains'])} subdomains")
    print(f"Found {len(results['live_hosts'])} live hosts")
```

### Discord Bot Integration

```python
#!/usr/bin/env python3
# ghost_bot.py - Discord bot for GHOST

import discord
import subprocess
from discord.ext import commands

bot = commands.Bot(command_prefix="!")

@bot.command()
async def scan(ctx, domain: str):
    """Trigger GHOST scan via Discord."""
    await ctx.send(f"🔍 Starting scan on `{domain}`...")
    
    # Run scan
    process = subprocess.Popen(
        ["./ghost.sh", "-d", domain, "--recon-only"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, stderr = process.communicate()
    
    if process.returncode == 0:
        await ctx.send(f"✅ Scan complete for `{domain}`!")
    else:
        await ctx.send(f"❌ Scan failed: {stderr.decode()}")

bot.run("YOUR_DISCORD_TOKEN")
```

---

## 💡 Tips & Tricks

### Speed Up Scans

```bash
# Use aggressive mode for authorized testing
./ghost.sh -d target.com -m aggressive

# Disable slow modules
export WAYBACK_ENABLED="false"
export GITHUB_DORK_ENABLED="false"
export EMAIL_HARVEST_ENABLED="false"

# Increase parallelism
export PARALLEL_JOBS="20"
```

### Reduce Noise

```bash
# Stealth mode + selective modules
./ghost.sh -d target.com -m stealth \
    --skip-vuln  # Manual vuln testing instead
```

### Focus on High-Value Targets

```bash
# After recon, filter targets
cat results/*/live_hosts.txt | \
    grep -E "(admin|api|dev|staging|test)" > \
    high_value_targets.txt

# Manual deep dive on these
```

---

<div align="center">

**Good luck hunting! 🎯👻**

</div>
