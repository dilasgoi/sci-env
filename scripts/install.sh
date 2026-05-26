#!/usr/bin/env bash
#==============================================================================
#
# Scientific Computing Environment Setup Script
#
# Description:
#   Installs Lua, Lmod, archspec, and EasyBuild into an arch-aware layout
#   and generates a runtime loader (init.sh) that handles per-host CPU
#   detection (including a built-in heuristic for Intel Sierra Forest CPUs
#   that archspec <= 0.2.6 misreads as 'skylake').
#
# Resulting layout (under the chosen prefix):
#   builds/<os>/<ver>/
#     common/                         arch-neutral tooling
#       software/{Lua,Lmod,EasyBuild}/<ver>/
#       modules/all/                  EasyBuild module lives here
#       build/
#     <arch>/                         created lazily by init.sh per host
#       software/  modules/all/  build/
#   src/                              shared EasyBuild source cache
#   tools/archspec/                   venv used by init.sh to detect CPU
#   init.sh                           generated runtime loader
#
# Deployment modes:
#   * Per-user (prefix under $HOME): the installer wires
#       source <prefix>/init.sh
#     into ~/.bashrc.
#   * System-wide (prefix outside $HOME, e.g. /scicomp): the installer leaves
#     ~/.bashrc alone and prints instructions to deploy init.sh as
#     /etc/profile.d/scicomp.sh on every node that mounts the prefix.
#
# Author: Diego Lasa
# License: MIT
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=utils/helpers.sh
source "${SCRIPT_DIR}/utils/helpers.sh"
# shellcheck source=utils/install_lua.sh
source "${SCRIPT_DIR}/utils/install_lua.sh"
# shellcheck source=utils/install_lmod.sh
source "${SCRIPT_DIR}/utils/install_lmod.sh"
# shellcheck source=utils/install_archspec.sh
source "${SCRIPT_DIR}/utils/install_archspec.sh"
# shellcheck source=utils/install_easybuild.sh
source "${SCRIPT_DIR}/utils/install_easybuild.sh"

#==============================================================================
# Defaults & argument parsing
#==============================================================================
LUA_VERSION="5.1.4.9"
LMOD_VERSION="8.7.59"
INSTALL_PREFIX="$HOME/scicomp"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)         show_help; exit 0 ;;
        -p|--prefix)       INSTALL_PREFIX="$2"; shift 2 ;;
        --lua-version)     LUA_VERSION="$2"; shift 2 ;;
        --lmod-version)    LMOD_VERSION="$2"; shift 2 ;;
        *) log "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

#==============================================================================
# Resolve OS slot
#==============================================================================
OS_INFO=$(detect_os_release) || exit 1
read -r OS_ID OS_MAJOR <<< "${OS_INFO}"

OS_ROOT="${INSTALL_PREFIX}/builds/${OS_ID}/${OS_MAJOR}"
COMMON_DIR="${OS_ROOT}/common"
SRC_DIR="${INSTALL_PREFIX}/src"

# Decide deploy mode early so downstream steps can gate on it. Prefix under
# $HOME is treated as a per-user install (we'll wire ~/.bashrc later);
# anything else is a system install (admin will copy init.sh to
# /etc/profile.d/ themselves).
case "${INSTALL_PREFIX}" in
    "${HOME}"|"${HOME}"/*) DEPLOY_MODE="user" ;;
    *)                     DEPLOY_MODE="system" ;;
esac

log "Layout:"
log "  prefix:   ${INSTALL_PREFIX}"
log "  os slot:  ${OS_ROOT}"
log "  common:   ${COMMON_DIR}"
log "  mode:     ${DEPLOY_MODE}"

# Warn early if previous-generation .bashrc gunk is around (would shadow the
# new init.sh exports). Only relevant for per-user installs; in system mode
# $HOME is whoever ran sudo (often /root) and that file isn't what loads on
# user logins anyway.
if [ "${DEPLOY_MODE}" = "user" ] && {
    grep -qE '^(export +)?EASYBUILD_(PREFIX|INSTALLPATH|MODULES_TOOL|SOURCEPATH|BUILDPATH)=' "${HOME}/.bashrc" 2>/dev/null \
    || grep -qE '^# EasyBuild configuration' "${HOME}/.bashrc" 2>/dev/null
}; then
    log "WARNING: ~/.bashrc contains EASYBUILD_* exports from an older sci-env install."
    log "         Remove that block manually; otherwise it will fight the new init.sh."
fi

#==============================================================================
# Directory skeleton
#==============================================================================
for dir in \
    "${SRC_DIR}/l/Lua" \
    "${SRC_DIR}/l/Lmod" \
    "${COMMON_DIR}/software" \
    "${COMMON_DIR}/modules/all" \
    "${COMMON_DIR}/build" \
    "${INSTALL_PREFIX}/tools"; do
    create_dir "${dir}"
done

#==============================================================================
# Install pipeline
#==============================================================================
install_system_dependencies

install_lua  "${LUA_VERSION}"  "${SRC_DIR}" "${COMMON_DIR}/software"
install_lmod "${LMOD_VERSION}" "${SRC_DIR}" "${COMMON_DIR}/software"

install_archspec "${INSTALL_PREFIX}"

install_easybuild "${INSTALL_PREFIX}" "${COMMON_DIR}" "${SRC_DIR}" "${LUA_VERSION}" "${LMOD_VERSION}"

#==============================================================================
# Generate the runtime loader
#==============================================================================
INIT_TEMPLATE="${SCRIPT_DIR}/templates/init.sh.in"
INIT_DEST="${INSTALL_PREFIX}/init.sh"

if [ ! -r "${INIT_TEMPLATE}" ]; then
    log "ERROR: init.sh template not found at ${INIT_TEMPLATE}"
    exit 1
fi

log "Generating runtime loader at ${INIT_DEST}..."
sed -e "s|@SCICOMP_PREFIX@|${INSTALL_PREFIX}|g" \
    -e "s|@LUA_VERSION@|${LUA_VERSION}|g" \
    -e "s|@LMOD_VERSION@|${LMOD_VERSION}|g" \
    "${INIT_TEMPLATE}" > "${INIT_DEST}"
chmod 0644 "${INIT_DEST}"
check_status "Generated ${INIT_DEST}"

# Copy validate.sh into tools/ so any node mounting the prefix can run it
# without cloning the repo.
VALIDATE_SRC="${SCRIPT_DIR}/validate.sh"
VALIDATE_DEST="${INSTALL_PREFIX}/tools/validate.sh"
install -m 0755 "${VALIDATE_SRC}" "${VALIDATE_DEST}"
check_status "Installed ${VALIDATE_DEST}"

#==============================================================================
# Per-user mode: wire the loader into ~/.bashrc (system mode does nothing
# here; admin is responsible for copying init.sh to /etc/profile.d/).
#==============================================================================
if [ "${DEPLOY_MODE}" = "user" ]; then
    if ! grep -qF "source ${INIT_DEST}" "${HOME}/.bashrc" 2>/dev/null; then
        printf '\n# sci-env runtime loader\nsource %s\n' "${INIT_DEST}" >> "${HOME}/.bashrc"
        check_status "Wired ${INIT_DEST} into ~/.bashrc"
    fi
fi

#==============================================================================
# Smoke test: source the just-generated init.sh in a subshell, then defer
# to validate.sh (the same script admins run on each node post-deploy).
# Subshell isolation keeps the installer's env unchanged.
#==============================================================================
log "Running smoke test (delegates to ${VALIDATE_DEST})..."
(
    set +u
    # shellcheck disable=SC1090
    source "${INIT_DEST}"
    "${VALIDATE_DEST}"
)
check_status "Smoke test"

#==============================================================================
# Summary
#==============================================================================
cat <<EOF

Installation Summary
--------------------
Prefix:        ${INSTALL_PREFIX}
OS slot:       ${OS_ROOT}
Common tree:   ${COMMON_DIR}
Source cache:  ${SRC_DIR}
archspec venv: ${INSTALL_PREFIX}/tools/archspec
Runtime init:  ${INIT_DEST}
Deploy mode:   ${DEPLOY_MODE}

Lua ${LUA_VERSION}, Lmod ${LMOD_VERSION}, archspec (latest), EasyBuild (latest release).

EOF

if [ "${DEPLOY_MODE}" = "user" ]; then
    cat <<EOF
Per-user install. The runtime loader is wired into ~/.bashrc.
Open a new shell or 'source ~/.bashrc', then verify with:

    module avail
    module load EasyBuild
    eb --version
    ${INSTALL_PREFIX}/tools/validate.sh   # health check

EOF
else
    cat <<EOF
System-wide install. Deploy the runtime loader on every node that mounts
${INSTALL_PREFIX}:

    sudo install -m 0644 ${INIT_DEST} /etc/profile.d/scicomp.sh

The loader auto-detects the host microarchitecture via archspec (with a
built-in fallback for Intel Sierra Forest, which archspec <= 0.2.6 misreads
as 'skylake') and routes EASYBUILD_INSTALLPATH/MODULEPATH to the matching
slot. Compiler optimization flags (-march/-mtune) stay EasyBuild's
responsibility; override per build with 'eb --optarch=...' if needed.

After deploying, on each node:

    module avail
    echo \$SCICOMP_ACTIVE_ARCH
    ${INSTALL_PREFIX}/tools/validate.sh   # health check

EOF
fi

exit 0
