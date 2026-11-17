#!/usr/bin/env bash

set -euo pipefail

# ==========================================
# GLOBAL CONFIGURATION
# ==========================================

VERSION="v3.3.0"
ARCHIVE_NAME="evilginx-v3.3.0-linux-64bit.zip"

SHA256="3ba7ec45c5017f57077a98ed61ce1f24dacddfb4928c20351aba2c0ae4398e39"

RELEASE_API="https://api.github.com/repos/kgretzky/evilginx2/releases/latest"

# ==========================================
# INSTALLATION PATH
# ==========================================

if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi

EXTRACT_DIR="$USER_HOME/evilginx-lab/extracted"

# ==========================================
# HELPERS
# ==========================================

log() {
    echo "$1"
}


# ==========================================
# ENVIRONMENT
# ==========================================

check_environment() {
    log "[*] Checking environment..."

    if [[ "$(uname -s)" != "Linux" ]]; then
        log "[-] Linux is required."
        return 1
    fi

    if [[ "$(uname -m)" != "x86_64" ]]; then
        log "[-] Unsupported architecture."
        return 1
    fi

    log "[+] Environment check passed."
}

# ==========================================
# DEPENDENCIES CHECK & INSTALLATION
# ==========================================

check_dependencies() {
    log "[*] Checking dependencies..."

    local dependency
    local missing_packages=()

    # Command -> APT package
    declare -A packages=(
        [curl]="curl"
        [jq]="jq"
        [unzip]="unzip"
        [sha256sum]="coreutils"
        [getent]="libc-bin"
        [awk]="gawk"
        [expect]="expect"
        [sort]="coreutils"
        [grep]="grep"
        [mktemp]="coreutils"
    )

    for dependency in "${!packages[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            log "[!] Missing dependency: $dependency"
            missing_packages+=("${packages[$dependency]}")
        fi
    done

    if (( ${#missing_packages[@]} == 0 )); then
        log "[+] All required dependencies are available."
        return 0
    fi

    # Remove duplicate package names
    mapfile -t missing_packages < <(
        printf '%s\n' "${missing_packages[@]}" | sort -u
    )

    if ! command -v apt-get >/dev/null 2>&1; then
        log "[-] Automatic installation requires apt-get."
        return 1
    fi

    log "[*] Installing missing packages: ${missing_packages[*]}"

    if (( EUID == 0 )); then
        apt-get update
        apt-get install -y "${missing_packages[@]}"
    else
        sudo apt-get update
        sudo apt-get install -y "${missing_packages[@]}"
    fi

    # Verify installation
    for dependency in "${!packages[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            log "[-] Dependency installation failed: $dependency"
            return 1
        fi
    done

    log "[+] All required dependencies installed successfully."
}

# ==========================================
# ARGUMENT VALIDATION
# ==========================================

parse_arguments() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <domain> <ipv4>" >&2
        return 1
    fi

    DOMAIN="${1,,}"
    PUBLIC_IP="$2"

    # Validate domain length
    if (( ${#DOMAIN} > 253 )); then
        log "[-] Domain exceeds 253 characters."
        return 1
    fi

    # Validate domain format
    if [[ ! "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]]; then
        log "[-] Invalid domain: $DOMAIN"
        return 1
    fi

    # Reject labels longer than 63 characters
    local label
    local -a labels

    IFS='.' read -r -a labels <<< "$DOMAIN"

    for label in "${labels[@]}"; do
        if (( ${#label} > 63 )); then
            log "[-] Domain label exceeds 63 characters."
            return 1
        fi
    done

    # Validate IPv4 format
    if [[ ! "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        log "[-] Invalid IPv4 format: $PUBLIC_IP"
        return 1
    fi

    # Validate each IPv4 octet
    local octet
    local -a octets

    IFS='.' read -r -a octets <<< "$PUBLIC_IP"

    for octet in "${octets[@]}"; do
        if (( 10#$octet > 255 )); then
            log "[-] Invalid IPv4 octet: $octet"
            return 1
        fi
    done

    log "[+] Domain and IPv4 validation passed."
}

# ==========================================
# DNS CHECK
# ==========================================

check_dns() {
    log "[*] Checking DNS records..."

    if ! command -v getent >/dev/null 2>&1; then
        log "[-] getent is not installed."
        return 1
    fi

    local resolved_ips

    resolved_ips=$(getent ahostsv4 "$DOMAIN" | awk '{print $1}' | sort -u) || true

    if [[ -z "$resolved_ips" ]]; then
        log "[-] Could not resolve domain: $DOMAIN"
        return 1
    fi

    log "[+] Resolved IPv4 addresses:"
    printf '%s\n' "$resolved_ips"

    if printf '%s\n' "$resolved_ips" | grep -Fxq "$PUBLIC_IP"; then
        log "[+] DNS matches the expected IPv4 address."
    else
        log "[!] DNS does not match the expected IP: $PUBLIC_IP"
        return 1
    fi
}

# ==========================================
# CHECKSUM VERIFICATION
# ==========================================

verify_checksum() {
    local archive="$1"

    log "[*] Verifying SHA256..."

    if [[ ! -f "$archive" ]]; then
        log "[-] Archive not found: $archive"
        return 1
    fi

    if printf '%s  %s\n' "$SHA256" "$archive" | sha256sum --check --status; then
        log "[+] SHA256 verification successful."
    else
        log "[-] SHA256 mismatch."
        return 1
    fi
}

# ==========================================
# ZIP VALIDATION
# ==========================================

validate_archive() {
    local archive="$1"

    log "[*] Validating ZIP archive..."

    if [[ ! -f "$archive" ]]; then
        log "[-] Archive not found: $archive"
        return 1
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        log "[-] unzip is not installed."
        return 1
    fi

    if unzip -tq "$archive" >/dev/null; then
        log "[+] ZIP integrity verification successful."
    else
        log "[-] ZIP integrity verification failed."
        return 1
    fi
}

# ==========================================
# GITHUB RELEASE CHECK
# ==========================================

check_github_release() {
    log "[*] Checking GitHub release..."

    if ! command -v curl >/dev/null 2>&1; then
        log "[-] curl is not installed."
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log "[-] jq is not installed."
        return 1
    fi

    local release_json
    local latest_version

    if ! release_json=$(curl -fsSL \
        --connect-timeout 10 \
        --max-time 30 \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: evilginx-lab-check" \
        "$RELEASE_API"); then

        log "[-] Failed to retrieve GitHub release."
        return 1
    fi

    if ! latest_version=$(jq -er '.tag_name' <<< "$release_json"); then
        log "[-] Invalid release metadata."
        return 1
    fi

    log "[+] Latest release: $latest_version"

    if [[ "$latest_version" != "$VERSION" ]]; then
        log "[-] Version mismatch."
        log "[-] Expected: $VERSION"
        log "[-] Found: $latest_version"
        return 1
    fi

    log "[+] Release version verified."
}

# ==========================================
# DOWNLOAD RELEASE
# ==========================================

download_evilginx() {
    local download_url
    local destination="$1"

    log "[*] Retrieving download URL..."

    download_url=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: evilginx-lab-check" \
        "$RELEASE_API" |
        jq -er --arg name "$ARCHIVE_NAME" \
        '.assets[] | select(.name == $name) | .browser_download_url'
    ) || {
        log "[-] Could not retrieve release download URL."
        return 1
    }

    log "[*] Downloading $ARCHIVE_NAME..."

    if ! curl -fL \
        --retry 3 \
        --connect-timeout 10 \
        --max-time 120 \
        -o "$destination" \
        "$download_url"; then

        rm -f -- "$destination"
        log "[-] Download failed."
        return 1
    fi

    log "[+] Download completed."
}

# ==========================================
# PERMANENT ARCHIVE EXTRACTION
# ==========================================

extract_archive() {
    local archive="$1"
    local destination="$2"

    log "[*] Extracting archive..."

    if [[ ! -f "$archive" ]]; then
        log "[-] Archive not found: $archive"
        return 1
    fi

    if [[ -e "$destination" ]]; then
        log "[-] Destination already exists: $destination"
        return 1
    fi

    mkdir -p -- "$destination"

    if ! unzip -q "$archive" -d "$destination"; then
        rm -rf -- "$destination"
        log "[-] Extraction failed."
        return 1
    fi

    log "[+] Archive extracted successfully."
    log "[+] Permanent location: $destination"
}

# ==========================================
# SET EXECUTABLE
# ==========================================

set_executable() {
    local binary="$1"

    if [[ ! -f "$binary" ]]; then
        echo "[-] Binary not found: $binary"
        return 1
    fi

    chmod +x "$binary"
    echo "[+] Execute permission granted: $binary"
}

# ==========================================
# LAUNCHING
# ==========================================

launch_application() {
    local binary="$EXTRACT_DIR/evilginx"

    if [[ ! -x "$binary" ]]; then
        echo "[-] Executable not found."
        return 1
    fi

    echo "[*] Launching application..."
    BINARY="$binary"
    export BINARY DOMAIN PUBLIC_IP
    expect -c '
set timeout 20
set binary $env(BINARY)
set DOMAIN $env(DOMAIN)
set PUBLIC_IP $env(PUBLIC_IP)
spawn $binary

send -- "config ipv4 external $PUBLIC_IP\r"
send -- "config domain $DOMAIN\r"
interact
'
}


# ==========================================
# MAIN
# ==========================================

main() {
    parse_arguments "$@"

    log "[+] Domain: $DOMAIN"
    log "[+] Public IPv4: $PUBLIC_IP"

    check_environment
    check_dependencies
    check_github_release

    if ! check_dns; then
        log "[!] DNS check did not pass."
    fi

    # Verify & downloaded archive
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf -- '$temp_dir'" EXIT
    local archive="$temp_dir/$ARCHIVE_NAME"
    download_evilginx "$archive"
    verify_checksum "$archive"
    validate_archive "$archive"
    extract_archive "$archive" "$EXTRACT_DIR"
    log "[+] Installation directory: $EXTRACT_DIR"
    log "[+] All validation checks completed."
    set_executable "$EXTRACT_DIR/evilginx"
    launch_application
}

main "$@"
