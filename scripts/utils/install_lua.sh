#!/usr/bin/env bash
# scripts/utils/install_lua.sh
# Lua installation functions

install_lua() {
    local lua_version=$1
    local src_dir=$2
    local software_dir=$3

    log "Installing Lua ${lua_version}..."
    cd "${src_dir}/l/Lua"
    if [ ! -f "lua-${lua_version}.tar.bz2" ]; then
        wget "https://sourceforge.net/projects/lmod/files/lua-${lua_version}.tar.bz2"
        check_status "Downloading Lua"
    fi

    bzip2 -df "lua-${lua_version}.tar.bz2"
    tar -xf "lua-${lua_version}.tar"
    cd "lua-${lua_version}"

    # Add missing header include
    sed -i '1i#include <string.h>' loadsys/unx_sys.c

    ./configure --prefix="${software_dir}/Lua/${lua_version}"
    make
    make install
    check_status "Installing Lua"

    # Initialize and set environment variables safely
    export CPATH="${CPATH:-}"
    export PATH="${PATH:-}"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"

    export CPATH="${software_dir}/Lua/${lua_version}/include${CPATH:+:$CPATH}"
    export PATH="${software_dir}/Lua/${lua_version}/bin${PATH:+:$PATH}"
    export LD_LIBRARY_PATH="${software_dir}/Lua/${lua_version}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
}

