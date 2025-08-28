#!/usr/bin/env bash
#==============================================================================
# Main Test Framework
# Location: tests/test_utils/test_framework.sh
#==============================================================================

set -euo pipefail

# Establish base paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
UTILS_DIR="${PROJECT_ROOT}/scripts/utils"

# Source required files
source "${SCRIPT_DIR}/test_helpers.sh"
source "${UTILS_DIR}/helpers.sh"
source "${UTILS_DIR}/install_lua.sh"
source "${UTILS_DIR}/install_lmod.sh"
source "${UTILS_DIR}/install_easybuild.sh"

# Test Environment Setup
TEST_PREFIX="/tmp/scicomp_test"
TEST_LUA_VERSION="${TEST_LUA_VERSION:-5.1.4.9}"      # Can be overridden by env var
TEST_LMOD_VERSION="${TEST_LMOD_VERSION:-8.7.53}"     # Can be overridden by env var

# Helper function to setup module environment
setup_module_env() {
    # Initialize module environment variables
    export LMOD_DIR="${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/libexec"
    export LMOD_PKG="${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod"
    export MODULESHOME="${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod"
    export MODULEPATH="${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/modulefiles/Core:${TEST_PREFIX}/modules/all"
    export MODULEPATH_ROOT="${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/modulefiles"
    export LMOD_CMD="${LMOD_DIR}/lmod"
}

# Global test environment setup
setup_test_environment() {
    log "Setting up test environment..."
    cleanup_test_env
    mkdir -p "${TEST_PREFIX}"/{src/l/{Lua,Lmod},software,modules/all,build}
    
    # Create clean home directory for tests
    export HOME="/tmp/test_home_$$"
    mkdir -p "$HOME"
    touch "$HOME/.bashrc"

    # Initialize all environment variables
    setup_module_env
    export PATH="${PATH:-}"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
    export FPATH="${FPATH:-}"
    export MANPATH="${MANPATH:-}"
    export INFOPATH="${INFOPATH:-}"
    export BASH_ENV="${BASH_ENV:-}"
}

# Global test environment cleanup
cleanup_test_env() {
    log "Cleaning up test environment..."
    rm -rf "${TEST_PREFIX}" "/tmp/eb_tmp" "/tmp/eb_venv_$USER" "/tmp/test_home_$$" 2>/dev/null || true
}

#==============================================================================
# Component-Level Test Functions
#==============================================================================

test_lua_component() {
    log "Testing Lua component..."
    
    # First test: Installation
    run_test "Lua Installation" "
        cd ${TEST_PREFIX}/src/l/Lua &&
        install_lua ${TEST_LUA_VERSION} ${TEST_PREFIX}/src ${TEST_PREFIX}/software &&
        [ -x ${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/bin/lua ] &&
        ${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/bin/lua -v
    "

    # Update PATH and LD_LIBRARY_PATH for the environment test
    export PATH="${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/bin:${PATH}"
    export LD_LIBRARY_PATH="${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Second test: Environment
    run_test "Lua Environment" "
        # Verify lua is in PATH
        FOUND_LUA=\$(which lua) &&
        echo \"Found Lua at: \${FOUND_LUA}\" &&
        [[ \"\${FOUND_LUA}\" == \"${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/bin/lua\" ]] &&
        
        # Verify LD_LIBRARY_PATH
        [[ \":\${LD_LIBRARY_PATH}:\" == *\":${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/lib:\"* ]] &&
        
        # Test Lua functionality
        lua -e 'print(\"Lua environment test successful\")' || exit 1
    "
}

test_lmod_component() {
    log "Testing Lmod component..."
    
    # Ensure Lua is in PATH for Lmod installation
    export PATH="${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/bin:$PATH"
    export LD_LIBRARY_PATH="${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    
    # First test: Installation
    run_test "Lmod Installation" "
        cd ${TEST_PREFIX}/src/l/Lmod &&
        install_lmod ${TEST_LMOD_VERSION} ${TEST_PREFIX}/src ${TEST_PREFIX}/software ${TEST_PREFIX} &&
        [ -f ${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/init/profile ]
    "

    # Setup Lmod environment
    setup_module_env

    # Second test: Environment and Functionality
    run_test "Lmod Environment" "
        source ${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/init/profile &&
        module --version &&
        echo \"MODULEPATH: \${MODULEPATH}\" &&
        [[ \":\${MODULEPATH}:\" == *\":${TEST_PREFIX}/modules/all:\"* ]]
    "
}

test_easybuild_component() {
    log "Testing EasyBuild component..."
    
    # Ensure Lmod is properly initialized
    source "${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/init/profile"
    
    # First test: Installation (pass versions)
    run_test "EasyBuild Installation" "
        install_easybuild ${TEST_PREFIX} ${TEST_PREFIX}/src ${TEST_PREFIX}/build ${TEST_LUA_VERSION} ${TEST_LMOD_VERSION} &&
        [ -d ${TEST_PREFIX}/modules/all/EasyBuild ] &&
        module --ignore_cache spider EasyBuild && 
        module --ignore_cache load EasyBuild &&
        command -v eb >/dev/null 2>&1
    "

    # Second test: Configuration and Environment
    run_test "EasyBuild Configuration" "
        [ -d ${TEST_PREFIX}/modules/all/EasyBuild ] &&
        module --ignore_cache load EasyBuild &&
        eb --version &&
        grep -q 'EASYBUILD_PREFIX=${TEST_PREFIX}' ${HOME}/.bashrc &&
        grep -q 'EASYBUILD_INSTALLPATH=${TEST_PREFIX}' ${HOME}/.bashrc &&
        grep -q 'EASYBUILD_SOURCEPATH=${TEST_PREFIX}/src' ${HOME}/.bashrc
    "
}

#==============================================================================
# Integration Test Functions
#==============================================================================

test_complete_installation() {
    log "Testing complete installation sequence..."
    
    run_test "Complete Installation" "
        # Run installation with specified versions
        ${PROJECT_ROOT}/scripts/install.sh -p ${TEST_PREFIX} --lua-version ${TEST_LUA_VERSION} --lmod-version ${TEST_LMOD_VERSION} &&
        [ -d ${TEST_PREFIX}/software ] &&
        [ -d ${TEST_PREFIX}/modules/all ] &&
        
        # Setup environment
        setup_module_env &&
        echo \"Initial MODULEPATH: \${MODULEPATH}\" &&
        
        # Source Lmod and verify MODULEPATH
        source ${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/init/profile &&
        echo \"MODULEPATH after source: \${MODULEPATH}\" &&
        
        # Rebuild cache and verify modules
        module --ignore_cache purge &&
        module --ignore_cache refresh &&
        echo \"Available modules:\" &&
        module --ignore_cache avail &&
        
        # Try loading EasyBuild
        module --ignore_cache spider EasyBuild &&
        module --ignore_cache load EasyBuild &&
        command -v eb >/dev/null 2>&1 &&
        eb --version
    "
}

test_environment_configuration() {
    log "Testing environment configuration..."
    
    # First ensure the environment is properly set up
    export PATH="${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/bin:${PATH}"
    export LD_LIBRARY_PATH="${TEST_PREFIX}/software/Lua/${TEST_LUA_VERSION}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    setup_module_env
    
    run_test "Environment Configuration" "
        # Echo current environment for debugging
        echo \"Initial MODULEPATH: \${MODULEPATH}\" &&
        
        # Source Lmod profile
        source ${TEST_PREFIX}/software/Lmod/${TEST_LMOD_VERSION}/lmod/lmod/init/profile &&
        echo \"MODULEPATH after source: \${MODULEPATH}\" &&
        
        # Rebuild module cache
        module --ignore_cache purge &&
        module --ignore_cache refresh &&
        
        # Debug output
        echo \"Current PATH: \${PATH}\" &&
        echo \"Current LD_LIBRARY_PATH: \${LD_LIBRARY_PATH}\" &&
        echo \"Final MODULEPATH: \${MODULEPATH}\" &&
        
        # Test environment
        module --ignore_cache avail &&
        module --ignore_cache spider EasyBuild &&
        module --ignore_cache load EasyBuild &&
        command -v eb >/dev/null 2>&1 &&
        eb --version &&
        
        # Verify configuration persistence
        grep -q 'EASYBUILD_PREFIX' ${HOME}/.bashrc &&
        grep -q 'source.*Lmod.*profile' ${HOME}/.bashrc
    "
}

#==============================================================================
# Main Test Functions
#==============================================================================

# Run component tests individually
run_component_tests() {
    setup_test_environment
    
    # Run tests in dependency order
    test_lua_component || return 1
    test_lmod_component || return 1
    test_easybuild_component || return 1
    
    cleanup_test_env
}

# Run full integration test
run_integration_tests() {
    setup_test_environment
    
    # Run complete installation and configuration tests
    test_complete_installation || return 1
    test_environment_configuration || return 1
    
    cleanup_test_env
}
