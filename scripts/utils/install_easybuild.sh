#!/usr/bin/env bash
# scripts/utils/install_easybuild.sh
# Bootstraps EasyBuild into the common slot of the arch-aware tree:
#   ${common_dir}/software/EasyBuild/<ver>/
#   ${common_dir}/modules/all/EasyBuild/<ver>.lua
# The runtime loader (init.sh) is responsible for EASYBUILD_* exports at
# login time, so this script does NOT modify ~/.bashrc.

install_easybuild() {
    local install_prefix=$1
    local common_dir=$2
    local src_dir=$3
    local lua_version=$4
    local lmod_version=$5

    log "Bootstrapping EasyBuild into ${common_dir}..."

    # Throw-away venv just to drive 'eb --install-latest-eb-release'.
    local temp_venv="/tmp/eb_venv_${USER:-$(id -un)}"
    rm -rf "${temp_venv}"
    python3 -m venv "${temp_venv}"
    {
        set +u
        # shellcheck disable=SC1091
        source "${temp_venv}/bin/activate"
        set -u
    }
    check_status "Creating temporary EasyBuild venv"

    python3 -m pip install --quiet --upgrade pip setuptools
    check_status "Bootstrapping pip"

    python3 -m pip install --quiet easybuild
    check_status "Installing EasyBuild in venv"

    # Set up Lua + Lmod from the freshly-built common/ tree so 'eb' can
    # produce a module. None of these exports persist past the script run;
    # the runtime init.sh re-derives them per-arch at login time.
    export FPATH="${FPATH:-}"
    export LMOD_PACKAGE_PATH="${LMOD_PACKAGE_PATH:-}"
    export LMOD_CONFIG_DIR="${LMOD_CONFIG_DIR:-}"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"

    export PATH="${common_dir}/software/Lua/${lua_version}/bin:${PATH}"
    export LD_LIBRARY_PATH="${common_dir}/software/Lua/${lua_version}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

    export LMOD_DIR="${common_dir}/software/Lmod/${lmod_version}/lmod/lmod/libexec"
    export LMOD_CMD="${LMOD_DIR}/lmod"
    export MODULESHOME="${common_dir}/software/Lmod/${lmod_version}/lmod/lmod"
    export MODULEPATH="${common_dir}/modules/all"
    export MODULEPATH_ROOT="${common_dir}/software/Lmod/${lmod_version}/lmod/lmod/modulefiles"
    export BASH_ENV="/dev/null"

    log "Sourcing Lmod..."
    # shellcheck disable=SC1091
    source "${common_dir}/software/Lmod/${lmod_version}/lmod/lmod/init/profile"
    check_status "Sourcing Lmod"

    if ! command -v module >/dev/null 2>&1; then
        log "ERROR: module command not available after sourcing Lmod"
        exit 1
    fi

    # Point EasyBuild at the common slot for this one-shot bootstrap.
    export EASYBUILD_PREFIX="${common_dir}"
    export EASYBUILD_INSTALLPATH="${common_dir}"
    export EASYBUILD_MODULES_TOOL=Lmod
    export EASYBUILD_INSTALLPATH_MODULES="${common_dir}/modules"
    export EASYBUILD_SOURCEPATH="${src_dir}"
    export EASYBUILD_BUILDPATH="${common_dir}/build"

    log "Installing EasyBuild permanently in ${common_dir}..."
    eb --installpath="${common_dir}" \
       --install-latest-eb-release \
       --sourcepath="${src_dir}" \
       --buildpath="${common_dir}/build" \
       --prefix="${common_dir}"
    check_status "Permanent EasyBuild installation"

    log "Cleaning up temporary EasyBuild venv..."
    {
        set +u
        deactivate
        set -u
    }
    rm -rf "${temp_venv}"
    check_status "Cleanup of temporary venv"
}
