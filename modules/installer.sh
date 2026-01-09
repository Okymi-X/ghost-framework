#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Smart Installer Module
# ==============================================================================
# File: modules/installer.sh
# Description: Auto-healing dependency installer for Go, Python, and security tools
# License: MIT
# 
# This module checks for and installs all required dependencies automatically.
# It follows the "auto-heal" philosophy - if something is missing, fix it.
# ==============================================================================

# Required Go version
readonly REQUIRED_GO_VERSION="1.21"
readonly GO_INSTALL_URL="https://go.dev/dl/go1.21.5.linux-amd64.tar.gz"

# List of required Go tools with their install paths
declare -A GO_TOOLS=(
    ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
    ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    ["katana"]="github.com/projectdiscovery/katana/cmd/katana@latest"
    ["dnsx"]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    ["gau"]="github.com/lc/gau/v2/cmd/gau@latest"
    ["gf"]="github.com/tomnomnom/gf@latest"
    ["dalfox"]="github.com/hahwul/dalfox/v2@latest"
    ["anew"]="github.com/tomnomnom/anew@latest"
    ["unfurl"]="github.com/tomnomnom/unfurl@latest"
    ["qsreplace"]="github.com/tomnomnom/qsreplace@latest"
    # New v1.1 tools
    ["naabu"]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    ["ffuf"]="github.com/ffuf/ffuf/v2@latest"
    ["gowitness"]="github.com/sensepost/gowitness@latest"
    ["subjack"]="github.com/haccer/subjack@latest"
    ["amass"]="github.com/owasp-amass/amass/v4/...@master"
    ["assetfinder"]="github.com/tomnomnom/assetfinder@latest"
)

# List of required system packages
readonly SYSTEM_PACKAGES="curl git jq wget unzip chromium"

# List of required Python packages
readonly PYTHON_PACKAGES="requests colorama"

# ------------------------------------------------------------------------------
# check_root()
# Check if running as root (needed for some installations)
# Returns: 0 if root, 1 if not
# ------------------------------------------------------------------------------
check_root() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# detect_package_manager()
# Detect the system's package manager
# Returns: Package manager command (apt, yum, pacman, brew)
# ------------------------------------------------------------------------------
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# ------------------------------------------------------------------------------
# install_system_package()
# Install a system package using the detected package manager
# Arguments: $1 = Package name
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
install_system_package() {
    local package="$1"
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    log_info "Installing system package: $package"
    
    case "$pkg_manager" in
        apt)
            sudo apt-get update -qq && sudo apt-get install -y -qq "$package"
            ;;
        yum)
            sudo yum install -y -q "$package"
            ;;
        dnf)
            sudo dnf install -y -q "$package"
            ;;
        pacman)
            sudo pacman -S --noconfirm --quiet "$package"
            ;;
        brew)
            brew install "$package"
            ;;
        *)
            log_error "Unknown package manager. Please install $package manually."
            return 1
            ;;
    esac
    
    return $?
}

# ------------------------------------------------------------------------------
# check_go_installed()
# Check if Go is installed and meets version requirements
# Returns: 0 if Go is installed and sufficient, 1 otherwise
# ------------------------------------------------------------------------------
check_go_installed() {
    if ! command -v go &> /dev/null; then
        log_warn "Go is not installed"
        return 1
    fi
    
    local go_version
    go_version=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+' | head -1)
    
    if [ -z "$go_version" ]; then
        log_warn "Could not determine Go version"
        return 1
    fi
    
    # Compare versions (simple numeric comparison)
    local required_major required_minor current_major current_minor
    required_major=$(echo "$REQUIRED_GO_VERSION" | cut -d. -f1)
    required_minor=$(echo "$REQUIRED_GO_VERSION" | cut -d. -f2)
    current_major=$(echo "$go_version" | cut -d. -f1)
    current_minor=$(echo "$go_version" | cut -d. -f2)
    
    if [ "$current_major" -gt "$required_major" ]; then
        return 0
    elif [ "$current_major" -eq "$required_major" ] && [ "$current_minor" -ge "$required_minor" ]; then
        return 0
    else
        log_warn "Go version $go_version is below required $REQUIRED_GO_VERSION"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# install_go()
# Download and install Go
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
install_go() {
    log_section "Installing Go ${REQUIRED_GO_VERSION}"
    
    local tmp_dir="/tmp/go_install_$$"
    mkdir -p "$tmp_dir"
    
    log_info "Downloading Go..."
    if ! wget -q "$GO_INSTALL_URL" -O "$tmp_dir/go.tar.gz"; then
        log_error "Failed to download Go"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    log_info "Extracting Go..."
    # Remove old Go installation if exists
    sudo rm -rf /usr/local/go
    
    if ! sudo tar -C /usr/local -xzf "$tmp_dir/go.tar.gz"; then
        log_error "Failed to extract Go"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # Clean up
    rm -rf "$tmp_dir"
    
    # Setup Go environment
    setup_go_environment
    
    log_success "Go installed successfully"
    return 0
}

# ------------------------------------------------------------------------------
# setup_go_environment()
# Configure Go environment variables
# ------------------------------------------------------------------------------
setup_go_environment() {
    # Export for current session
    export GOROOT="/usr/local/go"
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"
    
    # Add to shell profile for persistence
    local profile_file="$HOME/.bashrc"
    if [ -f "$HOME/.zshrc" ]; then
        profile_file="$HOME/.zshrc"
    fi
    
    # Check if already configured
    if ! grep -q "GOROOT" "$profile_file" 2>/dev/null; then
        cat >> "$profile_file" << 'EOF'

# Go environment (Added by GHOST-FRAMEWORK)
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"
export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"
EOF
        log_info "Go environment added to $profile_file"
    fi
    
    # Create Go directories
    mkdir -p "$GOPATH/bin" "$GOPATH/src" "$GOPATH/pkg"
}

# ------------------------------------------------------------------------------
# check_tool_installed()
# Check if a specific tool is installed and in PATH
# Arguments: $1 = Tool name
# Returns: 0 if installed, 1 if not
# ------------------------------------------------------------------------------
check_tool_installed() {
    local tool="$1"
    
    if command -v "$tool" &> /dev/null; then
        return 0
    fi
    
    # Also check in GOPATH/bin
    if [ -x "$HOME/go/bin/$tool" ]; then
        return 0
    fi
    
    return 1
}

# ------------------------------------------------------------------------------
# install_go_tool()
# Install a Go-based tool
# Arguments: $1 = Tool name, $2 = Install path
# Returns: 0 on success, 1 on failure
# ------------------------------------------------------------------------------
install_go_tool() {
    local tool="$1"
    local install_path="$2"
    
    log_info "Installing $tool..."
    
    # Ensure Go environment is set
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"
    
    if go install "$install_path" 2>/dev/null; then
        if check_tool_installed "$tool"; then
            log_success "$tool installed successfully"
            return 0
        fi
    fi
    
    log_error "Failed to install $tool"
    return 1
}

# ------------------------------------------------------------------------------
# install_gf_patterns()
# Install GF patterns for parameter discovery
# ------------------------------------------------------------------------------
install_gf_patterns() {
    log_info "Installing GF patterns..."
    
    local gf_dir="$HOME/.gf"
    mkdir -p "$gf_dir"
    
    # Clone popular GF patterns
    if [ ! -d "/tmp/Gf-Patterns" ]; then
        git clone -q https://github.com/1ndianl33t/Gf-Patterns.git /tmp/Gf-Patterns 2>/dev/null
    fi
    
    if [ -d "/tmp/Gf-Patterns" ]; then
        cp /tmp/Gf-Patterns/*.json "$gf_dir/" 2>/dev/null
        log_success "GF patterns installed to $gf_dir"
    fi
}

# ------------------------------------------------------------------------------
# update_nuclei_templates()
# Update Nuclei templates to the latest version
# ------------------------------------------------------------------------------
update_nuclei_templates() {
    if check_tool_installed "nuclei"; then
        log_info "Updating Nuclei templates..."
        nuclei -update-templates -silent 2>/dev/null
        log_success "Nuclei templates updated"
    fi
}

# ------------------------------------------------------------------------------
# check_python_installed()
# Check if Python 3 is installed
# Returns: 0 if installed, 1 if not
# ------------------------------------------------------------------------------
check_python_installed() {
    if command -v python3 &> /dev/null; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# install_python_packages()
# Install required Python packages
# ------------------------------------------------------------------------------
install_python_packages() {
    if ! check_python_installed; then
        log_warn "Python 3 is not installed. Installing..."
        install_system_package "python3"
        install_system_package "python3-pip"
    fi
    
    log_info "Installing Python packages..."
    for package in $PYTHON_PACKAGES; do
        pip3 install --quiet --user "$package" 2>/dev/null
    done
}

# ------------------------------------------------------------------------------
# run_installer()
# Main installer function - checks and installs all dependencies
# Arguments: $1 = "full" for complete install, "check" for check only
# Returns: 0 if all deps satisfied, 1 if issues remain
# ------------------------------------------------------------------------------
run_installer() {
    local mode="${1:-full}"
    local failed=0
    
    print_section "GHOST-FRAMEWORK Dependency Installer"
    
    # Track installation progress
    local total_steps=4
    local current_step=0
    
    # Step 1: System packages
    current_step=$((current_step + 1))
    print_step "$current_step" "$total_steps" "Checking system packages..."
    
    for package in $SYSTEM_PACKAGES; do
        if ! command -v "$package" &> /dev/null; then
            if [ "$mode" = "full" ]; then
                if ! install_system_package "$package"; then
                    log_warn "Could not install $package"
                    failed=1
                fi
            else
                log_warn "Missing: $package"
                failed=1
            fi
        else
            log_debug "$package: OK"
        fi
    done
    
    # Step 2: Go installation
    current_step=$((current_step + 1))
    print_step "$current_step" "$total_steps" "Checking Go installation..."
    
    if ! check_go_installed; then
        if [ "$mode" = "full" ]; then
            if ! install_go; then
                log_error "Go installation failed. Cannot continue with Go tools."
                return 1
            fi
        else
            log_warn "Go is not installed or outdated"
            failed=1
        fi
    else
        log_success "Go: OK ($(go version | grep -oP 'go[0-9]+\.[0-9]+\.[0-9]+'))"
        setup_go_environment
    fi
    
    # Step 3: Go tools
    current_step=$((current_step + 1))
    print_step "$current_step" "$total_steps" "Checking security tools..."
    
    local tool_count=${#GO_TOOLS[@]}
    local installed_count=0
    
    for tool in "${!GO_TOOLS[@]}"; do
        if check_tool_installed "$tool"; then
            log_debug "$tool: OK"
            installed_count=$((installed_count + 1))
        else
            if [ "$mode" = "full" ]; then
                if install_go_tool "$tool" "${GO_TOOLS[$tool]}"; then
                    installed_count=$((installed_count + 1))
                else
                    failed=1
                fi
            else
                log_warn "Missing: $tool"
                failed=1
            fi
        fi
    done
    
    log_info "Tools installed: $installed_count/$tool_count"
    
    # Step 4: Additional setup
    current_step=$((current_step + 1))
    print_step "$current_step" "$total_steps" "Running additional setup..."
    
    if [ "$mode" = "full" ]; then
        install_gf_patterns
        update_nuclei_templates
        install_python_packages
    fi
    
    # Summary
    echo ""
    if [ "$failed" -eq 0 ]; then
        print_success "All dependencies are installed and ready!"
        return 0
    else
        print_warning "Some dependencies could not be installed."
        print_info "Run with 'full' mode to attempt automatic installation."
        return 1
    fi
}

# ------------------------------------------------------------------------------
# show_installed_versions()
# Display versions of all installed tools
# ------------------------------------------------------------------------------
show_installed_versions() {
    print_section "Installed Tool Versions"
    
    echo ""
    printf "%-15s %s\n" "Tool" "Version"
    echo "─────────────────────────────────────"
    
    # Go version
    if command -v go &> /dev/null; then
        printf "%-15s %s\n" "go" "$(go version | awk '{print $3}')"
    fi
    
    # Security tools
    for tool in "${!GO_TOOLS[@]}"; do
        if check_tool_installed "$tool"; then
            local version
            version=$("$tool" -version 2>/dev/null | head -1 || echo "installed")
            printf "%-15s %s\n" "$tool" "$version"
        else
            printf "%-15s %s\n" "$tool" "(not installed)"
        fi
    done
}

# ------------------------------------------------------------------------------
# If run directly (not sourced), execute installer
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Source utilities if available
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/../utils/banner.sh" ]; then
        source "$SCRIPT_DIR/../utils/banner.sh"
    fi
    if [ -f "$SCRIPT_DIR/../utils/logger.sh" ]; then
        source "$SCRIPT_DIR/../utils/logger.sh"
    fi
    
    run_installer "${1:-full}"
fi
