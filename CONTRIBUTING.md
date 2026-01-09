# Contributing to GHOST-FRAMEWORK

First off, thank you for considering contributing to GHOST-FRAMEWORK! 🎉

It's people like you that make GHOST-FRAMEWORK such a great tool for the security community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Guidelines](#development-guidelines)
- [Pull Request Process](#pull-request-process)
- [Style Guide](#style-guide)
- [Module Development](#module-development)

---

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the maintainers.

### Our Standards

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

---

## Getting Started

### Prerequisites

- Bash 4.0+
- Go 1.21+
- Git
- A Unix-like environment (Linux, macOS, WSL2)

### Setting Up Development Environment

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/ghost-framework.git
cd ghost-framework

# 3. Add upstream remote
git remote add upstream https://github.com/Okymi-X/ghost-framework.git

# 4. Install dependencies
./ghost.sh --install

# 5. Create a branch for your work
git checkout -b feature/your-feature-name
```

### Testing Your Changes

```bash
# Check shell syntax
bash -n ghost.sh
bash -n modules/*.sh
bash -n utils/*.sh

# Run ShellCheck (recommended)
shellcheck ghost.sh modules/*.sh utils/*.sh

# Test basic functionality
./ghost.sh -h
./ghost.sh --version
./ghost.sh -d example.com --recon-only
```

---

## How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

**When reporting a bug, include:**

- Your operating system and version
- Bash version (`bash --version`)
- Go version (`go version`)
- Full error output
- Steps to reproduce
- Expected vs actual behavior

**Bug Report Template:**

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
1. Run command '...'
2. With arguments '...'
3. See error

**Expected behavior**
What you expected to happen.

**Environment:**
- OS: [e.g., Ubuntu 22.04]
- Bash: [e.g., 5.1.16]
- Go: [e.g., 1.21.5]

**Additional context**
Any other relevant information.
```

### 💡 Suggesting Features

We welcome feature suggestions! Please create an issue with:

- Clear description of the feature
- Use case / why it would be useful
- Proposed implementation (if you have ideas)
- Whether you're willing to implement it

### 📝 Improving Documentation

Documentation improvements are always welcome:

- Fix typos or grammatical errors
- Improve clarity of explanations
- Add usage examples
- Translate to other languages

### 🔧 Submitting Code

1. Check if there's an existing issue for what you want to work on
2. If not, create one to discuss your approach
3. Fork and create a branch
4. Write your code following our style guide
5. Test thoroughly
6. Submit a pull request

---

## Development Guidelines

### Branching Strategy

- `main` - Stable, production-ready code
- `develop` - Integration branch for features
- `feature/*` - New features
- `bugfix/*` - Bug fixes
- `hotfix/*` - Urgent fixes for production

### Commit Messages

Follow the conventional commits specification:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting, no code change
- `refactor` - Code restructuring
- `test` - Adding tests
- `chore` - Maintenance

**Examples:**
```
feat(recon): add support for SecurityTrails API
fix(crawler): handle timeout errors gracefully
docs(readme): add installation instructions for macOS
```

---

## Pull Request Process

1. **Update Documentation**: If you've changed functionality, update the README and inline comments.

2. **Follow Style Guide**: Ensure your code follows our Bash style guide.

3. **Test Thoroughly**: Run your code against test targets and edge cases.

4. **Create Clear PR Description**:
   - What does this PR do?
   - Why is this change needed?
   - How has it been tested?
   - Any breaking changes?

5. **Link Related Issues**: Use "Fixes #123" or "Closes #123" to link issues.

6. **Be Responsive**: Address review feedback promptly.

### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How did you test these changes?

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-reviewed my code
- [ ] Commented complex code areas
- [ ] Updated documentation
- [ ] No new warnings generated
- [ ] Tested on [OS versions]

## Related Issues
Fixes #(issue number)
```

---

## Style Guide

### Bash Style Guidelines

#### Shebang and Header

```bash
#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Module Name
# ==============================================================================
# File: filename.sh
# Description: Brief description
# License: MIT
# ==============================================================================
```

#### Variables

```bash
# Constants: UPPERCASE with underscores
readonly MAX_THREADS=50
readonly API_ENDPOINT="https://api.example.com"

# Local variables: lowercase with underscores
local file_count=0
local output_dir="/tmp/results"

# Use meaningful names
# Good:
subdomain_count=$(wc -l < subdomains.txt)

# Bad:
x=$(wc -l < subdomains.txt)
```

#### Functions

```bash
# Use snake_case for function names
# Always include description comment
# Document arguments and return values

# ------------------------------------------------------------------------------
# function_name()
# Brief description of what the function does
# Arguments: $1 = First arg, $2 = Second arg
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
function_name() {
    local arg1="$1"
    local arg2="$2"
    
    # Function body
    return 0
}
```

#### Error Handling

```bash
# Always check command success
if ! command_that_might_fail; then
    log_error "Command failed"
    return 1
fi

# Or use set -e for strict mode (with caution)
set -o errexit
set -o pipefail
```

#### Quoting

```bash
# Always quote variables
echo "$variable"
command "$file_path"

# Use arrays for multiple items
local files=("file1.txt" "file2.txt")
for file in "${files[@]}"; do
    process "$file"
done
```

#### Comments

```bash
# Use comments to explain WHY, not WHAT

# Bad:
# Increment counter by 1
counter=$((counter + 1))

# Good:
# Track attempts for retry logic (max 3 attempts)
counter=$((counter + 1))
```

### POSIX Compliance

While we primarily target Bash 4.0+, try to use POSIX-compliant constructs where possible:

```bash
# Prefer
command -v tool > /dev/null 2>&1

# Over
which tool > /dev/null 2>&1
```

---

## Module Development

Want to add a new module? Follow this guide:

### Module Template

```bash
#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Your Module Name
# ==============================================================================
# File: modules/your_module.sh
# Description: What this module does
# License: MIT
# ==============================================================================

# Module-specific constants
readonly MODULE_VERSION="1.0.0"

# ------------------------------------------------------------------------------
# your_main_function()
# Main entry point for this module
# Arguments: $1 = Required input
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
your_main_function() {
    local input="$1"
    
    print_section "Your Module Name"
    log_info "Starting module..."
    
    # Your logic here
    
    log_success "Module completed"
    return 0
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), show usage
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Your Module"
    echo "Usage: source your_module.sh && your_main_function <input>"
fi
```

### Integration Checklist

- [ ] Module follows the template structure
- [ ] Uses `log_info`, `log_error`, `log_success` for output
- [ ] Uses `print_section` for visual organization
- [ ] Respects `IS_WAF` flag if applicable
- [ ] Reads from config variables where appropriate
- [ ] Writes output to the workspace directory
- [ ] Has proper error handling
- [ ] Is sourced in `ghost.sh`

---

## Questions?

If you're unsure about anything, feel free to:

1. Open an issue with the "question" label
2. Join our Discord community
3. Ask in pull request comments

Thank you for contributing! 🙏
