#!/usr/bin/env bash
#==============================================================================
#
# Scientific Computing Environment Setup Script
#
# Description:
#   Automated installation and configuration of a scientific computing environment
#   including Lua, Lmod (Module System), and EasyBuild (Software Build/Installation
#   Framework). This script sets up a complete environment in the user's home
#   directory or specified location.
#
# Components installed:
#   - Lua 5.1.4.9 (Required for Lmod)
#   - Lmod 8.7.59 (Module System)
#   - EasyBuild (Latest version via bootstrap)
#
# Author: Diego Lasa
# Date: 2024-11-24
# License: MIT
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/helpers.sh"
source "${SCRIPT_DIR}/utils/install_lua.sh"
source "${SCRIPT_DIR}/utils/install_lmod.sh"
source "${SCRIPT_DIR}/utils/install_easybuild.sh"

#==============================================================================
# Default Configuration
#==============================================================================
LUA_VERSION="5.1.4.9"
LMOD_VERSION="8.7.59"

#==============================================================================
# Parse Command Line Arguments
#==============================================================================
INSTALL_PREFIX="$HOME/scicomp"
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --lua-version)
            LUA_VERSION="$2"
            shift 2
            ;;
        --lmod-version)
            LMOD_VERSION="$2"
            shift 2
            ;;
        *)
            log "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

#==============================================================================
# Directory Setup
#==============================================================================
SRC_DIR="${INSTALL_PREFIX}/src"
SOFTWARE_DIR="${INSTALL_PREFIX}/software"
BUILD_DIR="${INSTALL_PREFIX}/build"
MODULES_DIR="${INSTALL_PREFIX}/modules"

# Create directory structure
for dir in "$SRC_DIR" "$SOFTWARE_DIR" "$BUILD_DIR" "${SRC_DIR}/l/Lua" "${SRC_DIR}/l/Lmod" "$MODULES_DIR/all"; do
    create_dir "$dir"
done

#==============================================================================
# Main Installation Process
#==============================================================================
# Install system dependencies
install_system_dependencies

# Install Lua (pass the version explicitly)
install_lua "$LUA_VERSION" "$SRC_DIR" "$SOFTWARE_DIR"

# Install and configure Lmod (pass the version explicitly)
install_lmod "$LMOD_VERSION" "$SRC_DIR" "$SOFTWARE_DIR" "$INSTALL_PREFIX"

# Install and configure EasyBuild (pass both versions)
install_easybuild "$INSTALL_PREFIX" "$SRC_DIR" "$BUILD_DIR" "$LUA_VERSION" "$LMOD_VERSION"

# Clean up temporary files
cleanup

#==============================================================================
# Final Configuration
#==============================================================================
log "Setting up final configuration..."

# Set BASHRCSOURCED to prevent unbound variable error
export BASHRCSOURCED="Y"

# Source bashrc in a subshell to prevent script termination if there are errors
if (source "$HOME/.bashrc" >/dev/null 2>&1); then
    log "Successfully sourced .bashrc"
else
    log "Warning: Could not source .bashrc completely, but installation is complete"
    log "You will need to run 'source ~/.bashrc' manually after the script finishes"
fi

#==============================================================================
# Installation Summary
#==============================================================================
cat << EOF

Installation Summary:
--------------------
Lua Version: ${LUA_VERSION}
Lua Path: ${SOFTWARE_DIR}/Lua/${LUA_VERSION}
Lmod Version: ${LMOD_VERSION}
Lmod Path: ${SOFTWARE_DIR}/Lmod/${LMOD_VERSION}
EasyBuild Path: ${INSTALL_PREFIX}

Module Paths:
- ${SOFTWARE_DIR}/Lmod/${LMOD_VERSION}/lmod/lmod/modulefiles/Core
- ${INSTALL_PREFIX}/modules/all

EasyBuild Configuration:
- Prefix: ${INSTALL_PREFIX}
- Modules Tool: Lmod
- Modules Path: ${INSTALL_PREFIX}/modules
- Source Path: ${INSTALL_PREFIX}/src
- Build Path: ${INSTALL_PREFIX}/build

Next steps:
1. Run 'source ~/.bashrc'
2. Run 'module av' to verify Lmod installation
3. Run 'module load EasyBuild' to load EasyBuild

Note: The environment will be fully functional after a new login session or
      after sourcing ~/.bashrc
EOF

# Exit successfully
exit 0
