#!/bin/bash
# ==============================================================================
# GHOST-FRAMEWORK - Nuclei Template Builder
# ==============================================================================
# File: modules/templates.sh
# Description: Create custom Nuclei templates from discovered patterns
# License: MIT
# Version: 1.3.0
# ==============================================================================

# Template output directory
TEMPLATES_DIR="${TEMPLATES_DIR:-$HOME/.nuclei-templates/custom-ghost}"

# ------------------------------------------------------------------------------
# init_templates_dir()
# Initialize custom templates directory
# ------------------------------------------------------------------------------
init_templates_dir() {
    mkdir -p "$TEMPLATES_DIR"
    log_debug "Templates directory: $TEMPLATES_DIR"
}

# ------------------------------------------------------------------------------
# generate_header_template()
# Generate template to detect specific header
# Arguments: $1 = Header name, $2 = Header value pattern, $3 = Severity
# ------------------------------------------------------------------------------
generate_header_template() {
    local header_name="$1"
    local value_pattern="$2"
    local severity="${3:-info}"
    local template_id
    template_id="header-$(echo "$header_name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')"
    
    local template_file="$TEMPLATES_DIR/${template_id}.yaml"
    
    cat > "$template_file" << EOF
id: ${template_id}

info:
  name: Detect $header_name Header
  author: ghost-framework
  severity: $severity
  description: Detects the presence of $header_name header
  tags: headers,custom

http:
  - method: GET
    path:
      - "{{BaseURL}}"
    
    matchers:
      - type: regex
        part: header
        regex:
          - "(?i)$header_name:\\s*$value_pattern"
EOF
    
    log_info "Created template: $template_file"
}

# ------------------------------------------------------------------------------
# generate_path_template()
# Generate template to detect accessible path
# Arguments: $1 = Path, $2 = Expected content pattern, $3 = Severity
# ------------------------------------------------------------------------------
generate_path_template() {
    local path="$1"
    local content_pattern="$2"
    local severity="${3:-info}"
    local template_id
    template_id="path-$(echo "$path" | tr -c 'a-z0-9' '-' | tr '[:upper:]' '[:lower:]')"
    
    local template_file="$TEMPLATES_DIR/${template_id}.yaml"
    
    cat > "$template_file" << EOF
id: ${template_id}

info:
  name: Detect Accessible Path - $path
  author: ghost-framework
  severity: $severity
  description: Checks if $path is accessible
  tags: paths,custom

http:
  - method: GET
    path:
      - "{{BaseURL}}/$path"
    
    matchers-condition: and
    matchers:
      - type: status
        status:
          - 200
      - type: word
        part: body
        words:
          - "$content_pattern"
EOF
    
    log_info "Created template: $template_file"
}

# ------------------------------------------------------------------------------
# generate_error_template()
# Generate template to detect error messages
# Arguments: $1 = Error pattern, $2 = Technology/Framework
# ------------------------------------------------------------------------------
generate_error_template() {
    local error_pattern="$1"
    local technology="$2"
    local template_id
    template_id="error-$(echo "$technology" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')"
    
    local template_file="$TEMPLATES_DIR/${template_id}.yaml"
    
    cat > "$template_file" << EOF
id: ${template_id}

info:
  name: $technology Error Disclosure
  author: ghost-framework
  severity: low
  description: Detects $technology error messages that may reveal sensitive information
  tags: error,disclosure,custom

http:
  - method: GET
    path:
      - "{{BaseURL}}"
      - "{{BaseURL}}/'"
      - "{{BaseURL}}/?id='"
    
    matchers:
      - type: regex
        part: body
        regex:
          - "$error_pattern"
EOF
    
    log_info "Created template: $template_file"
}

# ------------------------------------------------------------------------------
# generate_secret_template()
# Generate template to detect exposed secrets pattern
# Arguments: $1 = Pattern name, $2 = Regex pattern
# ------------------------------------------------------------------------------
generate_secret_template() {
    local pattern_name="$1"
    local regex_pattern="$2"
    local template_id
    template_id="secret-$(echo "$pattern_name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')"
    
    local template_file="$TEMPLATES_DIR/${template_id}.yaml"
    
    cat > "$template_file" << EOF
id: ${template_id}

info:
  name: Exposed $pattern_name
  author: ghost-framework
  severity: high
  description: Detects exposed $pattern_name in response
  tags: secrets,exposure,custom

http:
  - method: GET
    path:
      - "{{BaseURL}}"
    
    extractors:
      - type: regex
        part: body
        regex:
          - "$regex_pattern"
EOF
    
    log_info "Created template: $template_file"
}

# ------------------------------------------------------------------------------
# generate_cve_template()
# Generate template for specific CVE
# Arguments: $1 = CVE ID, $2 = Affected software, $3 = Check path, $4 = Check pattern
# ------------------------------------------------------------------------------
generate_cve_template() {
    local cve_id="$1"
    local software="$2"
    local check_path="$3"
    local check_pattern="$4"
    local template_id
    template_id="$(echo "$cve_id" | tr '[:upper:]' '[:lower:]')"
    
    local template_file="$TEMPLATES_DIR/${template_id}.yaml"
    
    cat > "$template_file" << EOF
id: ${template_id}

info:
  name: $cve_id - $software
  author: ghost-framework
  severity: critical
  description: Detects $cve_id in $software
  reference:
    - https://nvd.nist.gov/vuln/detail/${cve_id}
  tags: cve,${cve_id},custom

http:
  - method: GET
    path:
      - "{{BaseURL}}$check_path"
    
    matchers-condition: and
    matchers:
      - type: status
        status:
          - 200
      - type: word
        part: body
        words:
          - "$check_pattern"
EOF
    
    log_info "Created CVE template: $template_file"
}

# ------------------------------------------------------------------------------
# generate_from_findings()
# Auto-generate templates from scan findings
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
generate_from_findings() {
    local workspace="$1"
    
    log_info "Generating templates from findings..."
    
    init_templates_dir
    
    # Generate from tech detection
    if [ -f "$workspace/technologies/technologies.txt" ]; then
        while IFS= read -r line; do
            [[ "$line" == *"WordPress"* ]] && \
                generate_path_template "wp-login.php" "WordPress" "info"
            [[ "$line" == *"Drupal"* ]] && \
                generate_path_template "CHANGELOG.txt" "Drupal" "info"
            [[ "$line" == *"Laravel"* ]] && \
                generate_error_template "Laravel|Illuminate\\\\|Whoops" "Laravel"
        done < "$workspace/technologies/technologies.txt"
    fi
    
    # Generate from sensitive files found
    if [ -f "$workspace/fuzzing/all_sensitive.txt" ]; then
        while IFS= read -r line; do
            [[ "$line" == *".git"* ]] && \
                generate_path_template ".git/config" "\\[core\\]" "critical"
            [[ "$line" == *".env"* ]] && \
                generate_path_template ".env" "APP_KEY\\|DB_PASSWORD" "critical"
        done < "$workspace/fuzzing/all_sensitive.txt"
    fi
    
    # Generate for discovered API patterns
    if [ -f "$workspace/api/swagger_*.json" ]; then
        generate_path_template "swagger.json" "swagger" "info"
        generate_path_template "api-docs" "openapi\\|swagger" "info"
    fi
    
    log_success "Templates generated in $TEMPLATES_DIR"
}

# ------------------------------------------------------------------------------
# validate_templates()
# Validate generated templates
# ------------------------------------------------------------------------------
validate_templates() {
    log_info "Validating templates..."
    
    if ! command -v nuclei &>/dev/null; then
        log_warn "Nuclei not installed - skipping validation"
        return 1
    fi
    
    local valid=0
    local invalid=0
    
    for template in "$TEMPLATES_DIR"/*.yaml; do
        [ -f "$template" ] || continue
        
        if nuclei -validate -t "$template" 2>/dev/null | grep -q "Valid"; then
            valid=$((valid + 1))
        else
            invalid=$((invalid + 1))
            log_warn "Invalid template: $template"
        fi
    done
    
    log_info "Validation: $valid valid, $invalid invalid"
}

# ------------------------------------------------------------------------------
# run_custom_templates()
# Run scan with custom templates
# Arguments: $1 = Target list/file
# ------------------------------------------------------------------------------
run_custom_templates() {
    local targets="$1"
    
    if ! command -v nuclei &>/dev/null; then
        log_error "Nuclei not installed"
        return 1
    fi
    
    if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls -A "$TEMPLATES_DIR" 2>/dev/null)" ]; then
        log_warn "No custom templates found"
        return 1
    fi
    
    log_info "Running custom templates..."
    
    if [ -f "$targets" ]; then
        nuclei -l "$targets" -t "$TEMPLATES_DIR" -o /tmp/custom_results.txt
    else
        echo "$targets" | nuclei -t "$TEMPLATES_DIR" -o /tmp/custom_results.txt
    fi
}

# ------------------------------------------------------------------------------
# run_template_builder()
# Main template builder function
# Arguments: $1 = Workspace
# ------------------------------------------------------------------------------
run_template_builder() {
    local workspace="$1"
    
    print_section "Nuclei Template Builder"
    log_info "Workspace: $workspace"
    
    if [ "${TEMPLATE_BUILDER_ENABLED:-true}" != "true" ]; then
        log_info "Template builder disabled"
        return 0
    fi
    
    init_templates_dir
    
    # Generate templates from findings
    generate_from_findings "$workspace"
    
    # Validate
    validate_templates
    
    # Count templates
    local template_count
    template_count=$(find "$TEMPLATES_DIR" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    
    print_section "Template Builder Complete"
    log_success "Generated $template_count custom templates"
    log_info "Location: $TEMPLATES_DIR"
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GHOST-FRAMEWORK Nuclei Template Builder"
    echo ""
    echo "Usage:"
    echo "  source templates.sh"
    echo "  generate_header_template <name> <pattern> [severity]"
    echo "  generate_path_template <path> <content> [severity]"
    echo "  run_template_builder <workspace>"
fi
