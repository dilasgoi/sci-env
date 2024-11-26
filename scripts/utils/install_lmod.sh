#!/usr/bin/env bash
# scripts/utils/install_lmod.sh
# Lmod installation and configuration functions

install_lmod() {
    local lmod_version=$1
    local src_dir=$2
    local software_dir=$3
    local install_prefix=$4

    log "Installing Lmod ${lmod_version}..."
    cd "${src_dir}/l/Lmod"
    if [ ! -f "${lmod_version}.tar.gz" ]; then
        wget "https://github.com/TACC/Lmod/archive/refs/tags/${lmod_version}.tar.gz"
        check_status "Downloading Lmod"
    fi

    tar -zxf "${lmod_version}.tar.gz"
    cd "Lmod-${lmod_version}"
    ./configure --prefix="${software_dir}/Lmod/${lmod_version}"
    make install
    check_status "Installing Lmod"

    configure_lmod "${software_dir}" "${lmod_version}" "${install_prefix}"
}

configure_lmod() {
    local software_dir=$1
    local lmod_version=$2
    local install_prefix=$3
    local lmod_init="${software_dir}/Lmod/${lmod_version}/lmod/lmod/init/profile"

    log "Configuring module paths..."
    if ! grep -q "${install_prefix}/modules/all" "$lmod_init"; then
        CORE_LINE="export MODULEPATH=\$(.*modulefiles\/Core)"
        sed -i "/${CORE_LINE}/a export MODULEPATH=\$($software_dir/Lmod/${lmod_version}/lmod/lmod/libexec/addto --append MODULEPATH $install_prefix/modules/all)" "$lmod_init"
        check_status "Adding custom module path after Core modules in Lmod init file"
    fi

    if ! grep -q "source.*${lmod_init}" "$HOME/.bashrc"; then
        echo "source ${lmod_init}" >> "$HOME/.bashrc"
        check_status "Adding Lmod initialization to .bashrc"
    fi
}
