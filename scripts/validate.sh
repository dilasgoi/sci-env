#!/usr/bin/env bash
#==============================================================================
# sci-env validate
#
# Health check for a deployed sci-env environment. Run in a shell where
# init.sh has been sourced (login shell with /etc/profile.d/scicomp.sh in
# place, or a shell that sourced ${prefix}/init.sh manually).
#
# The installer copies this script to ${prefix}/tools/validate.sh so any
# node mounting the prefix can run it without cloning the repo.
#
# Exit 0 if every check passes, 1 otherwise. Failed checks print to stderr.
#==============================================================================

set -o pipefail

# Shell functions (like `module`) don't survive fork+exec, so when validate.sh
# is invoked as a child process the calling shell's `module` is not visible.
# Source init.sh once if it isn't already loaded in this process. Prefix is
# taken from SCICOMP_PREFIX (exported by init.sh) or derived from our own
# location (we live at ${prefix}/tools/validate.sh).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCICOMP_PREFIX="${SCICOMP_PREFIX:-$(dirname "${SCRIPT_DIR}")}"
if ! command -v module >/dev/null 2>&1 && [ -r "${SCICOMP_PREFIX}/init.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCICOMP_PREFIX}/init.sh"
fi

FAIL=0
pass() { printf '  OK   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1" >&2; FAIL=1; }

check_set() {
    local name=$1
    local value="${!name:-}"
    if [ -n "${value}" ]; then
        pass "${name} = ${value}"
    else
        fail "${name} is not set (was init.sh sourced in this shell?)"
    fi
}

printf '\n[1/4] Loader environment\n'
check_set SCICOMP_PREFIX
check_set SCICOMP_OS_ID
check_set SCICOMP_OS_MAJOR
check_set SCICOMP_ACTIVE_ARCH
check_set EASYBUILD_INSTALLPATH
check_set MODULEPATH

printf '\n[2/4] Filesystem coherence\n'
if [ -n "${SCICOMP_PREFIX:-}" ] && [ -n "${SCICOMP_OS_ID:-}" ] \
   && [ -n "${SCICOMP_OS_MAJOR:-}" ] && [ -n "${SCICOMP_ACTIVE_ARCH:-}" ]; then
    SLOT="${SCICOMP_PREFIX}/builds/${SCICOMP_OS_ID}/${SCICOMP_OS_MAJOR}/${SCICOMP_ACTIVE_ARCH}"
    if [ -d "${SLOT}" ]; then
        pass "host arch slot exists: ${SLOT}"
    else
        fail "host arch slot missing: ${SLOT}"
    fi
    if [ "${EASYBUILD_INSTALLPATH:-}" = "${SLOT}" ]; then
        pass "EASYBUILD_INSTALLPATH matches host arch slot"
    else
        fail "EASYBUILD_INSTALLPATH=${EASYBUILD_INSTALLPATH:-<unset>} != ${SLOT}"
    fi
else
    fail "filesystem checks skipped (loader vars missing above)"
fi

printf '\n[3/4] archspec venv\n'
ARCHSPEC_PY="${SCICOMP_PREFIX:-}/tools/archspec/bin/python"
if [ -x "${ARCHSPEC_PY}" ]; then
    if "${ARCHSPEC_PY}" -c 'import archspec.cpu as c; c.host()' 2>/dev/null; then
        pass "archspec venv at ${ARCHSPEC_PY} works"
    else
        fail "archspec venv at ${ARCHSPEC_PY} exists but import fails"
    fi
else
    fail "archspec venv python not executable: ${ARCHSPEC_PY}"
fi

printf '\n[4/4] Lmod + EasyBuild\n'
if command -v module >/dev/null 2>&1; then
    pass "module command available"
    # `--show-hidden` so a deployment that hides the EasyBuild module
    # (typical: rename to .X.Y.Z.lua so end users don't see it in
    # `module avail`) still passes this check, since the module is still
    # loadable and that's what we're verifying.
    if module --show-hidden avail 2>&1 | grep -q 'EasyBuild'; then
        pass "EasyBuild module reachable in MODULEPATH"
    else
        fail "EasyBuild module not reachable (check common/ slot is populated)"
    fi
else
    fail "module command not available (Lmod init/profile not sourced)"
fi

printf '\n'
if [ "${FAIL}" -eq 0 ]; then
    printf 'All checks passed.\n'
    exit 0
else
    printf 'One or more checks failed.\n' >&2
    exit 1
fi
