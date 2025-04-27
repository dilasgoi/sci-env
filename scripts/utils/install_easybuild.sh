#!/usr/bin/env bash

install_easybuild() {
    local install_prefix=$1
    local src_dir=$2
    local build_dir=$3
    local lua_version=$4
    local lmod_version=$5

    # Step 1: Create a temporary virtualenv for EasyBuild
    log "Creating temporary EasyBuild environment..."
    local temp_venv="/tmp/eb_venv_$USER"
    python3 -m venv "$temp_venv"
    {
        set +u  # Temporarily disable strict mode for source
        source "$temp_venv/bin/activate"
        set -u
    }
    check_status "Creating Python virtual environment"

    # Install required Python packages
    log "Installing Python dependencies..."
    python3 -m pip install --upgrade pip setuptools
    check_status "Installing setuptools"

    # Install EasyBuild in the virtualenv
    log "Installing EasyBuild in virtual environment..."
    python3 -m pip install easybuild
    check_status "Temporary EasyBuild installation"

    # Rest of the function remains the same...
    EASYBUILD_CONFIG="
# EasyBuild configuration
export EASYBUILD_PREFIX=${install_prefix}
export EASYBUILD_INSTALLPATH=${install_prefix}
export EASYBUILD_MODULES_TOOL=Lmod
export EASYBUILD_INSTALLPATH_MODULES=${install_prefix}/modules
export EASYBUILD_SOURCEPATH=${install_prefix}/src
export EASYBUILD_BUILDPATH=${install_prefix}/build
"
    if ! grep -q "EasyBuild configuration" "$HOME/.bashrc"; then
        echo "$EASYBUILD_CONFIG" >> "$HOME/.bashrc"
        check_status "Adding EasyBuild configuration to .bashrc"
    fi

    # Step 2: Configure environment for permanent installation
    log "Configuring environment..."
    
    # Initialize all potentially unbound variables
    export FPATH="${FPATH:-}"
    export LMOD_PACKAGE_PATH="${LMOD_PACKAGE_PATH:-}"
    export LMOD_CONFIG_DIR="${LMOD_CONFIG_DIR:-}"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
    
    # Setup Lua and Lmod environment (using variables instead of hardcoded values)
    export PATH="${install_prefix}/software/Lua/${lua_version}/bin:$PATH"
    export LD_LIBRARY_PATH="${install_prefix}/software/Lua/${lua_version}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    
    # Setup Lmod
    export LMOD_DIR="${install_prefix}/software/Lmod/${lmod_version}/lmod/lmod/libexec"
    export LMOD_CMD="${LMOD_DIR}/lmod"
    export MODULESHOME="${install_prefix}/software/Lmod/${lmod_version}/lmod/lmod"
    export MODULEPATH="${install_prefix}/modules/all"
    export MODULEPATH_ROOT="${install_prefix}/software/Lmod/${lmod_version}/lmod/lmod/modulefiles"
    export BASH_ENV="/dev/null"
    
    # Source Lmod
    log "Sourcing Lmod..."
    source "${install_prefix}/software/Lmod/${lmod_version}/lmod/lmod/init/profile"
    check_status "Sourcing Lmod"

    # Verify module command is available
    if ! command -v module >/dev/null 2>&1; then
        log "ERROR: module command not available after sourcing Lmod"
        exit 1
    fi

    # Apply EasyBuild environment variables
    export EASYBUILD_PREFIX="$install_prefix"
    export EASYBUILD_INSTALLPATH="$install_prefix"
    export EASYBUILD_MODULES_TOOL=Lmod
    export EASYBUILD_INSTALLPATH_MODULES="${install_prefix}/modules"
    export EASYBUILD_SOURCEPATH="${install_prefix}/src"
    export EASYBUILD_BUILDPATH="${install_prefix}/build"

    # Step 3: Permanent installation
    log "Installing EasyBuild permanently in ${install_prefix}..."
    eb --installpath="${install_prefix}" \
       --install-latest-eb-release \
       --sourcepath="${src_dir}" \
       --buildpath="${build_dir}" \
       --prefix="${install_prefix}"
    check_status "Permanent EasyBuild installation"

    # Cleanup
    log "Cleaning up temporary environment..."
    {
        set +u  # Temporarily disable strict mode for deactivate
        deactivate
        set -u
    }
    rm -rf "$temp_venv"
    check_status "Environment cleanup"
}
