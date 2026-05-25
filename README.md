# sci-env

A minimalist toolkit that automates the installation of scientific computing environments on Linux systems.
Sets up Lua, Lmod (module system), archspec (CPU detection), and EasyBuild (software build framework) into
an arch-aware layout, and generates a runtime loader (`init.sh`) that detects each host's CPU at login and
points EasyBuild at the right per-architecture slot. Supports both RHEL/Fedora and Debian/Ubuntu derivatives.
Designed for HPC clusters with NFS-shared software trees (one install, many nodes with different CPUs) and
for single-host scientific workstations.

## Components

- **[Lua](https://www.lua.org/)**: A lightweight, high-level scripting language designed for embedded use, configuration, and rapid prototyping. Known for its simplicity, efficiency, and excellent documentation. In this toolkit, it serves as the foundation for Lmod's module system implementation.

- **[Lmod](https://lmod.readthedocs.io/)**: A modern replacement for environment modules that handles the dynamic modification of a user's environment. It provides a sophisticated solution for managing multiple software versions and dependencies in HPC environments. Lmod uses Lua for its implementation, offering features like module caching, hierarchical dependencies, and support for module properties.

- **[archspec](https://github.com/archspec/archspec)**: A library that classifies the host CPU into a named microarchitecture (e.g. `icelake`, `cascadelake`, `skylake_avx512`) and exposes its ancestor chain. The runtime loader uses it to pick the correct per-architecture slot at login. A built-in heuristic in the loader patches archspec's blind spot for Intel Sierra Forest (Xeon 6 E-core, e.g. 6740E), which archspec <= 0.2.6 misreads as `skylake`.

- **[EasyBuild](https://easybuild.io/)**: An extensive software build and installation framework specifically designed for High Performance Computing (HPC) systems. It provides a consistent, reproducible approach to installing scientific software. EasyBuild includes thousands of ready-to-use build recipes (easyconfigs) for popular scientific software, handles dependencies automatically, and integrates seamlessly with environment modules.

These components work together to create a comprehensive scientific computing environment:
1. Lua provides the scripting foundation
2. Lmod manages the environment and software modules
3. archspec classifies the running host so each node picks ISA-appropriate binaries
4. EasyBuild automates the building and installation of scientific software

## Requirements

Supported operating systems:
- RHEL-based: RHEL, CentOS, Rocky Linux, AlmaLinux, Fedora
- Debian-based: Debian, Ubuntu

Install required development packages:

For RHEL-based systems:
```bash
sudo dnf install -y tk-devel tcl-devel python3-wheel python3-pip python3-devel
```

For Debian-based systems:
```bash
sudo apt-get update && sudo apt-get install -y tcl-dev tk-dev python3-wheel python3-pip python3-venv python3-dev
```

## Installation & Usage

The installer detects whether the chosen prefix is inside `$HOME` or outside, and configures the deployment accordingly. Same install pipeline, two deploy modes.

### Per-user install (single host, `$HOME` prefix)

```bash
git clone https://github.com/dilasgoi/sci-env.git
cd sci-env
./scripts/install.sh                # default prefix: $HOME/scicomp
source ~/.bashrc                    # installer wires init.sh into ~/.bashrc

module avail
module load EasyBuild
eb --version
```

### System-wide install (NFS-shared cluster, prefix outside `$HOME`)

```bash
# On a node with write access to the shared prefix (e.g. hera-01):
sudo ./scripts/install.sh -p /scicomp

# Then on every node that mounts /scicomp:
sudo install -m 0644 /scicomp/init.sh /etc/profile.d/scicomp.sh
```

At each login on each node, `init.sh`:

- Detects the host CPU via archspec (with a built-in fallback for Sierra Forest).
- Auto-creates `${prefix}/builds/<os>/<ver>/<arch>/{software,modules/all,build}/` if missing.
- Composes `MODULEPATH` as: host arch slot → compatible ancestor slots that exist → common slot.
- Exports `EASYBUILD_INSTALLPATH`/`EASYBUILD_BUILDPATH`/etc. pointing at the host's arch slot, so `eb` writes into the right place.

The loader only handles routing. Compiler optimization flags (`-march`/`-mtune`) stay EasyBuild's responsibility. Override per build with `eb --optarch=...` if you need to.

### Optional per-host CPU override

When archspec misdetects a CPU AND the built-in Sierra Forest heuristic doesn't catch it, force a target on that specific node:

```bash
sudo install -d /etc/scicomp
echo 'SCICOMP_HOST_ARCH=<archspec-target>' | sudo tee /etc/scicomp/host.conf
```

The init loader reads `host.conf` first; archspec then supplies its ancestor chain for the overridden target.

### CLI options

```
-h, --help              Show help message
-p, --prefix PATH       Installation prefix (default: $HOME/scicomp)
--lua-version VERSION   Lua version (default: 5.1.4.9)
--lmod-version VERSION  Lmod version (default: 8.7.59)
```

### Layout

```
$PREFIX/
├── builds/<os>/<ver>/
│   ├── common/                 # arch-neutral tooling (Lua, Lmod, EasyBuild)
│   │   ├── software/{Lua,Lmod,EasyBuild}/<ver>/
│   │   ├── modules/all/        # EasyBuild module lives here
│   │   └── build/
│   └── <arch>/                 # auto-created by init.sh on each node
│       ├── software/
│       ├── modules/all/
│       └── build/
├── src/                        # shared EasyBuild source cache
├── tools/archspec/             # venv used by init.sh for CPU detection
└── init.sh                     # generated runtime loader
```

### Day-to-day usage

```bash
module avail                                # see modules for this host's arch (+ ancestors + common)
module load EasyBuild
eb Python-3.11.3-GCCcore-12.3.0.eb --robot  # installs into ${prefix}/builds/<os>/<ver>/<arch>/

echo $SCICOMP_ACTIVE_ARCH                   # the arch the loader picked for this host
```

## Testing

> **Note:** the test suite under `tests/` was written against the legacy flat layout and has not yet been ported to the arch-aware layout. Tests will fail until updated. Re-validating end-to-end on a real cluster install is the current recommended verification path.

## Project Structure

```
sci-env/
├── scripts/
│   ├── install.sh                  # Main installer / orchestrator
│   ├── templates/
│   │   └── init.sh.in              # Runtime loader template (substituted at install)
│   └── utils/
│       ├── helpers.sh              # Common utilities (incl. OS detection)
│       ├── install_lua.sh          # Lua installer
│       ├── install_lmod.sh         # Lmod installer
│       ├── install_archspec.sh     # archspec venv installer
│       └── install_easybuild.sh    # EasyBuild bootstrap
└── tests/                          # Legacy; pending rewrite for arch-aware layout
```

## Troubleshooting

### Common Issues and Solutions

1. **Module command not found**
   ```bash
   # Per-user install: re-source bashrc
   source ~/.bashrc

   # System install: re-source the profile snippet (or open a new login shell)
   source /etc/profile.d/scicomp.sh
   ```

2. **Lua compilation fails**
   ```bash
   # For RHEL-based systems:
   sudo dnf install -y tk-devel tcl-devel

   # For Debian-based systems:
   sudo apt-get install -y tcl-dev tk-dev
   ```

3. **Python package installation fails**
   ```bash
   # For RHEL-based systems:
   sudo dnf install -y python3-devel python3-venv

   # For Debian-based systems:
   sudo apt-get install -y python3-dev python3-venv
   ```

4. **EasyBuild module not loading**
   ```bash
   # Solution: Rebuild module cache
   module --ignore_cache load EasyBuild
   ```

### Debug Mode

For detailed installation information:
```bash
# Run installation with debug output
bash -x scripts/install.sh

# Check environment variables
echo $MODULEPATH
echo $LD_LIBRARY_PATH

# Check package manager
if command -v dnf &> /dev/null; then
    echo "RHEL-based system detected"
elif command -v apt-get &> /dev/null; then
    echo "Debian-based system detected"
fi
```

## Component Details

Default stable versions (configurable via command line):
- Lua: 5.1.4.9
- Lmod: 8.7.59
- archspec: Latest from PyPI (installed into `${prefix}/tools/archspec/` venv)
- EasyBuild: Latest stable release (automatically selected during bootstrap)

Tested Distributions:
- RHEL and derivatives (RHEL, CentOS, Rocky Linux, AlmaLinux, Fedora)
- Debian and derivatives (Debian, Ubuntu)

Note: Lua and Lmod versions can be overridden during installation using the `--lua-version` and `--lmod-version` flags. The Lua/Lmod versions are baked into `init.sh` at install time; if you change them later, re-run the installer to regenerate `init.sh`.

## License

MIT License
