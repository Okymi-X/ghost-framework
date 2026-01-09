# Security Policy

## 🔒 Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.3.x   | ✅ Yes             |
| 1.2.x   | ✅ Yes             |
| 1.1.x   | ⚠️ Security only   |
| < 1.1   | ❌ No              |

## 🚨 Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### Do NOT

- ❌ Open a public GitHub issue
- ❌ Discuss on social media
- ❌ Share details publicly

### Do

1. **Contact via GitHub** - Create a private security advisory on GitHub or DM @Okymi-X

2. **Include in your report:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Your suggested fix (if any)

3. **Wait for response** (usually within 48 hours)

## ⏱️ Response Timeline

| Action | Timeframe |
|--------|-----------|
| Initial response | 48 hours |
| Vulnerability confirmed | 7 days |
| Patch developed | 14 days |
| Public disclosure | 30 days after fix |

## 🏆 Recognition

We appreciate security researchers and will:

- Credit you in the release notes (if desired)
- Add you to our Security Hall of Fame
- Consider bug bounty for critical issues

## 🔐 Security Best Practices

When using GHOST-FRAMEWORK:

1. **Never commit `ghost.conf` with API keys**
2. **Use environment variables for sensitive data**
3. **Run with minimal privileges when possible**
4. **Keep the framework updated**
5. **Only scan systems you're authorized to test**

## 📋 Security Checklist for Contributors

- [ ] No hardcoded credentials
- [ ] No sensitive data in logs
- [ ] Input validation implemented
- [ ] Safe command execution (no injection)
- [ ] Dependencies are up to date

---

Thank you for helping keep GHOST-FRAMEWORK secure! 🛡️

**Maintainer:** [Okymi-X](https://github.com/Okymi-X)
