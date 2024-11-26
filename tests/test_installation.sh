#!/usr/bin/env bash
#==============================================================================
# Integration Tests Entry Point
# Location: tests/test_installation.sh
#==============================================================================

set -euo pipefail

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/test_framework.sh"

# Run integration tests and print summary
if run_integration_tests; then
    print_test_summary
    exit 0
else
    print_test_summary
    exit 1
fi
