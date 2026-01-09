#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Banner & Color Utilities
# ==============================================================================
# File: utils/banner.sh
# Description: ASCII art banner and ANSI color definitions for terminal output
# License: MIT
# ==============================================================================

# ------------------------------------------------------------------------------
# ANSI Color Definitions
# Using standard ANSI escape codes for maximum compatibility
# ------------------------------------------------------------------------------
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'

# Bold variants
readonly COLOR_BOLD_RED='\033[1;31m'
readonly COLOR_BOLD_GREEN='\033[1;32m'
readonly COLOR_BOLD_YELLOW='\033[1;33m'
readonly COLOR_BOLD_BLUE='\033[1;34m'
readonly COLOR_BOLD_MAGENTA='\033[1;35m'
readonly COLOR_BOLD_CYAN='\033[1;36m'
readonly COLOR_BOLD_WHITE='\033[1;37m'

# Background colors
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'

# Framework version
readonly GHOST_VERSION="1.0.0"
readonly GHOST_CODENAME="Phantom"

# ------------------------------------------------------------------------------
# print_banner()
# Display the main ASCII art banner with version info
# ------------------------------------------------------------------------------
print_banner() {
    echo -e "${COLOR_BOLD_CYAN}"
    cat << 'EOF'
   ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
  ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
  ██║  ███╗███████║██║   ██║███████╗   ██║   
  ██║   ██║██╔══██║██║   ██║╚════██║   ██║   
  ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   
   ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   
EOF
    echo -e "${COLOR_RESET}"
    echo -e "${COLOR_BOLD_WHITE}  ═══════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_CYAN}  Bug Bounty Automation Framework${COLOR_RESET}"
    echo -e "${COLOR_MAGENTA}  Version: ${GHOST_VERSION} (${GHOST_CODENAME})${COLOR_RESET}"
    echo -e "${COLOR_BOLD_WHITE}  ═══════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# print_mini_banner()
# Display a compact version of the banner for module headers
# ------------------------------------------------------------------------------
print_mini_banner() {
    local module_name="${1:-GHOST}"
    echo -e "${COLOR_BOLD_CYAN}[GHOST]${COLOR_RESET} ${COLOR_WHITE}${module_name}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}────────────────────────────────────────${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# Color printing functions
# Usage: print_success "Your message here"
# ------------------------------------------------------------------------------

print_success() {
    echo -e "${COLOR_BOLD_GREEN}[✓]${COLOR_RESET} ${COLOR_GREEN}$1${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_BOLD_RED}[✗]${COLOR_RESET} ${COLOR_RED}$1${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_BOLD_YELLOW}[!]${COLOR_RESET} ${COLOR_YELLOW}$1${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_BOLD_BLUE}[i]${COLOR_RESET} ${COLOR_BLUE}$1${COLOR_RESET}"
}

print_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${COLOR_MAGENTA}[DEBUG]${COLOR_RESET} $1"
    fi
}

print_critical() {
    echo -e "${BG_RED}${COLOR_BOLD_WHITE}[CRITICAL]${COLOR_RESET} ${COLOR_BOLD_RED}$1${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# print_section()
# Display a section header for organizing output
# Arguments: $1 = Section title
# ------------------------------------------------------------------------------
print_section() {
    local title="$1"
    echo ""
    echo -e "${COLOR_BOLD_CYAN}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    printf "${COLOR_BOLD_CYAN}║${COLOR_RESET} ${COLOR_BOLD_WHITE}%-62s${COLOR_RESET} ${COLOR_BOLD_CYAN}║${COLOR_RESET}\n" "$title"
    echo -e "${COLOR_BOLD_CYAN}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# print_step()
# Display a numbered step in a process
# Arguments: $1 = Step number, $2 = Total steps, $3 = Description
# ------------------------------------------------------------------------------
print_step() {
    local current="$1"
    local total="$2"
    local desc="$3"
    echo -e "${COLOR_BOLD_CYAN}[${current}/${total}]${COLOR_RESET} ${COLOR_WHITE}${desc}${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# print_progress()
# Display a simple progress bar
# Arguments: $1 = Current value, $2 = Maximum value
# ------------------------------------------------------------------------------
print_progress() {
    local current="$1"
    local max="$2"
    local width=40
    local percentage=$((current * 100 / max))
    local filled=$((current * width / max))
    local empty=$((width - filled))
    
    printf "\r${COLOR_CYAN}[${COLOR_RESET}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${COLOR_CYAN}]${COLOR_RESET} ${COLOR_WHITE}%3d%%${COLOR_RESET}" "$percentage"
}

# ------------------------------------------------------------------------------
# print_table_header()
# Display a table header
# Arguments: Variable number of column names
# ------------------------------------------------------------------------------
print_table_header() {
    local sep="${COLOR_CYAN}│${COLOR_RESET}"
    echo -e "${COLOR_CYAN}┌────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    printf "${COLOR_CYAN}│${COLOR_RESET}"
    for col in "$@"; do
        printf " ${COLOR_BOLD_WHITE}%-20s${COLOR_RESET}" "$col"
    done
    printf "${COLOR_CYAN}│${COLOR_RESET}\n"
    echo -e "${COLOR_CYAN}├────────────────────────────────────────────────────────────────┤${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# print_table_row()
# Display a table row
# Arguments: Variable number of column values
# ------------------------------------------------------------------------------
print_table_row() {
    printf "${COLOR_CYAN}│${COLOR_RESET}"
    for val in "$@"; do
        printf " ${COLOR_WHITE}%-20s${COLOR_RESET}" "$val"
    done
    printf "${COLOR_CYAN}│${COLOR_RESET}\n"
}

# ------------------------------------------------------------------------------
# print_table_footer()
# Display a table footer
# ------------------------------------------------------------------------------
print_table_footer() {
    echo -e "${COLOR_CYAN}└────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
}
