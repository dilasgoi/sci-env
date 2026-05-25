#!/usr/bin/env bash
# scripts/utils/install_archspec.sh
# archspec venv installation. Placed under ${prefix}/tools/archspec so the
# runtime init.sh can call its python interpreter directly without polluting
# the user's PATH.

install_archspec() {
    local install_prefix=$1
    local tools_dir="${install_prefix}/tools/archspec"

    log "Installing archspec into ${tools_dir}..."

    if [ -x "${tools_dir}/bin/python" ]; then
        log "archspec venv already present; upgrading in place"
        "${tools_dir}/bin/pip" install --quiet --upgrade archspec
        check_status "archspec upgrade"
        return
    fi

    create_dir "$(dirname "${tools_dir}")"
    python3 -m venv "${tools_dir}"
    check_status "Creating archspec venv"

    "${tools_dir}/bin/pip" install --quiet --upgrade pip setuptools
    check_status "Bootstrapping archspec venv pip"

    "${tools_dir}/bin/pip" install --quiet archspec
    check_status "Installing archspec"
}
