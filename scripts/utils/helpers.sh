#!/usr/bin/env bash
# scripts/utils/helpers.sh

#==============================================================================
# Utility Functions
#==============================================================================
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
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

create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        check_status "Created directory $1"
    fi
}

cleanup() {
    log "Cleaning up temporary files..."
    OS_TYPE=$(detect_os)
    if [ "$OS_TYPE" = "rhel" ]; then
        rm -rf "/tmp/eb_tmp"
    elif [ "$OS_TYPE" = "debian" ]; then
        rm -rf "/tmp/pip-*"  # Ubuntu/Debian pip temp files
    fi
    check_status "Cleanup complete"
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
        sudo dnf install -y tk-devel tcl-devel python3-wheel python3-pip 
        check_status "Installing system dependencies with DNF"
    elif [ "$OS_TYPE" = "debian" ]; then
        sudo apt-get update && sudo apt-get install -y tcl-dev tk-dev python3-wheel python3-pip python3-venv
        check_status "Installing system dependencies with APT"
    fi
}
