#!/usr/bin/env bash
# scripts/utils/install_lmod.sh
# Lmod installation. The runtime loader (init.sh) sources Lmod's init/profile
# and exports MODULEPATH itself, so this script no longer patches the Lmod
# init file nor touches ~/.bashrc.

install_lmod() {
    local lmod_version=$1
    local src_dir=$2
    local software_dir=$3

    log "Installing Lmod ${lmod_version}..."
    cd "${src_dir}/l/Lmod"
    if [ ! -f "${lmod_version}.tar.gz" ]; then
        wget "https://github.com/TACC/Lmod/archive/refs/tags/${lmod_version}.tar.gz"
        check_status "Downloading Lmod"
    fi

    tar -zxf "${lmod_version}.tar.gz"
    cd "Lmod-${lmod_version}"
    ./configure --prefix="${software_dir}/Lmod/${lmod_version}"
    make -j"$(nproc)" install
    check_status "Installing Lmod"
}
