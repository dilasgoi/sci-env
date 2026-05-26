#!/usr/bin/env bash
# scripts/utils/helpers.sh

#==============================================================================
# Utility Functions
#==============================================================================
log() {
    # Status messages go to stderr so they don't pollute the stdout of
    # functions that return values via command substitution
    # (e.g. detect_os_release, detect_os). Users still see them at the
    # terminal; capture with '2>&1' or '2> install.log' if needed.
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

check_status() {
    if [ $? -eq 0 ]; then
        log "SUCCESS: $1"
    else
        log "ERROR: $1"
        exit 1
    fi
}

detect_os() {
    if command -v dnf &> /dev/null; then
        echo "rhel"
    elif command -v apt-get &> /dev/null; then
        echo "debian"
    else
        log "ERROR: Unsupported package manager. Only RHEL/Fedora derivatives and Ubuntu/Debian are supported."
        exit 1
    fi
}

# Resolve OS identity for the arch-aware layout. Prints "<id>\t<major>" from
# /etc/os-release (e.g. "rocky\t9", "ubuntu\t24"). Tab-separated so callers
# using `read` with strict IFS=$'\n\t' still split correctly. Returns
# non-zero if it cannot determine either field; callers should propagate
# the failure.
detect_os_release() {
    if [ ! -r /etc/os-release ]; then
        log "ERROR: /etc/os-release not readable"
        return 1
    fi
    local id ver
    id=$(
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID:-}" | tr '[:upper:]' '[:lower:]'
    )
    ver=$(
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${VERSION_ID:-}"
    )
    ver="${ver%%.*}"
    if [ -z "${id}" ] || [ -z "${ver}" ]; then
        log "ERROR: could not parse ID/VERSION_ID from /etc/os-release"
        return 1
    fi
    printf '%s\t%s\n' "${id}" "${ver}"
}

create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        check_status "Created directory $1"
    fi
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help              Show help message
    -p, --prefix PATH       Installation prefix (default: \$HOME/scicomp)
    --lua-version VERSION   Lua version (default: ${LUA_VERSION})
    --lmod-version VERSION  Lmod version (default: ${LMOD_VERSION})
EOF
}

install_system_dependencies() {
    log "Installing system dependencies..."
    OS_TYPE=$(detect_os)

    if [ "$OS_TYPE" = "rhel" ]; then
        sudo dnf install -y tk-devel tcl-devel python3-wheel python3-pip python3-devel
        check_status "Installing system dependencies with DNF"
    elif [ "$OS_TYPE" = "debian" ]; then
        sudo apt-get update && sudo apt-get install -y tcl-dev tk-dev python3-wheel python3-pip python3-venv python3-dev
        check_status "Installing system dependencies with APT"
    fi
}
