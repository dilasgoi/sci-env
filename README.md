# sci-env

A minimalist toolkit that automates the installation of scientific computing environments on Linux systems. 
Sets up Lua, Lmod (module system), and EasyBuild (software build framework) in a single user space, 
without root privileges after initial dependencies. Supports both RHEL/Fedora and Debian/Ubuntu derivatives, 
includes comprehensive testing, and requires no configuration files. 
Designed for HPC environments, research computing, and scientific workstations where reproducible software stacks are essential.

## Components

- **Lua**: A lightweight scripting language (required by Lmod)
- **Lmod**: A modern environment module system that manages software versions and dependencies
- **EasyBuild**: A powerful software build and installation framework for HPC systems

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

### Basic Setup

For most users, the default installation in your home directory is recommended:

```bash
# Clone the repository
git clone https://github.com/dilasgoi/sci-env.git
cd sci-env

# Run installation
./scripts/install.sh

# Activate your new environment
source ~/.bashrc

# Verify installation
module --version
module avail
```

### Advanced Installation Options

Install in a custom location:
```bash
# Install in a shared location
./scripts/install.sh -p /opt/scicomp

# Install with specific versions
./scripts/install.sh --lua-version 5.1.4.9 --lmod-version 8.7.53

# Get help on all options
./scripts/install.sh --help
```

### Using Your New Environment

After installation, you can:

```bash
# List available modules
module avail

# Load EasyBuild
module load EasyBuild

# Get information about EasyBuild
module help EasyBuild

# Show currently loaded modules
module list

# Search for specific software
module spider python

# Install new software with EasyBuild
eb Python-3.11.3-GCCcore-12.3.0.eb
```

Installation creates this structure:
```
$PREFIX/
├── build/          # EasyBuild build directory
├── modules/all/    # Module files for installed software
├── software/       # Installed components and software
└── src/           # Source files and archives
```

## Testing

sci-env includes a comprehensive testing framework to ensure reliable operation across different Linux distributions.

### Why Testing Matters

Our testing approach ensures:
- Each component works correctly in isolation
- Components work together as a system
- Installation succeeds in different environments
- System configurations are correct
- Environment variables are properly set
- Cross-distribution compatibility

### Types of Tests

#### Component Tests
Test individual parts of the system:
```bash
./tests/test_components.sh
```

These verify:
- Lua installation and functionality
- Lmod installation and basic module operations
- EasyBuild installation and configuration
- Environment variable setup
- Component dependencies
- Distribution-specific adaptations

Example component test output:
```
2024-11-25 15:10:23 - Starting component tests...
✓ Test passed: Lua Installation
✓ Test passed: Lua Environment
✓ Test passed: Lmod Installation
✓ Test passed: Lmod Environment
...
```

#### Integration Tests
Test the complete system working together:
```bash
./tests/test_installation.sh
```

These verify:
- Full installation process
- System-wide configuration
- Component interactions
- Module system functionality
- EasyBuild operations
- Cross-distribution compatibility

### Running Tests

```bash
# Run both test suites
./tests/test_components.sh
./tests/test_installation.sh

# Run with debug output
bash -x ./tests/test_components.sh
```

## Project Structure

```
sci-env/
├── scripts/
│   ├── install.sh                 # Main installer
│   └── utils/
│       ├── helpers.sh            # Common utilities
│       ├── install_easybuild.sh  # EasyBuild installer
│       ├── install_lmod.sh       # Lmod installer
│       └── install_lua.sh        # Lua installer
└── tests/
    ├── test_components.sh        # Component tests
    ├── test_installation.sh      # Integration tests
    └── utils/
        ├── test_framework.sh     # Test framework
        └── test_helpers.sh       # Test utilities
```

## Troubleshooting

### Common Issues and Solutions

1. **Module command not found**
   ```bash
   # Solution: Reload your environment
   source ~/.bashrc
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

Current stable versions:
- Lua: 5.1.4.9 (tested and stable version for Lmod)
- Lmod: 8.7.53 (includes hierarchical module features)
- EasyBuild: Latest stable version (automatically selected)

Tested Distributions:
- RHEL and derivatives (RHEL, CentOS, Rocky Linux, AlmaLinux, Fedora)
- Debian and derivatives (Debian, Ubuntu)

## Contributing

Contributions are welcome! Please feel free to submit pull requests. Areas of particular interest:
- Additional distribution support
- Enhanced testing coverage
- Performance improvements
- Documentation improvements

## License

MIT License

## Author

Diego Lasa

---

For more detailed information about individual components:
- [Lua Documentation](https://www.lua.org/docs.html)
- [Lmod Documentation](https://lmod.readthedocs.io/)
- [EasyBuild Documentation](https://docs.easybuild.io/)
