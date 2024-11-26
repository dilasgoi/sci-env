#!/usr/bin/env bash
#==============================================================================
# Test Helper Functions
#==============================================================================

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"
}

# Debug function for environment information
debug_environment() {
    echo "DEBUG: Current environment:"
    echo "PATH=$PATH"
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-not set}"
    echo "MODULEPATH=${MODULEPATH:-not set}"
    echo "Current directory: $(pwd)"
    echo "Lua executable:"
    command -v lua || echo "lua not found"
    echo "Module command:"
    command -v module || echo "module not found"
    echo "EasyBuild command:"
    command -v eb || echo "eb not found"
}

# Run a single test in a single subshell
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Running test: ${test_name}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Single subshell for the entire test
    if (
        set -e
        # Create clean test environment
        export HOME="/tmp/test_home_$$"
        mkdir -p "$HOME"
        touch "$HOME/.bashrc"
        
        # Execute test command
        eval "${test_command}"
    ); then
        echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed: ${test_name}${NC}"
        debug_environment
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Print test summary
print_test_summary() {
    echo "=============================="
    echo "Test Summary:"
    echo "Tests run: ${TESTS_RUN}"
    echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"
    echo "=============================="
    
    if [ ${TESTS_FAILED} -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}
