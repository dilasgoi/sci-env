#!/usr/bin/env bash
#==============================================================================
# Component Tests Entry Point
# Location: tests/test_components.sh
#==============================================================================

set -euo pipefail

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/test_framework.sh"

# Run component tests and print summary
if run_component_tests; then
    print_test_summary
    exit 0
else
    print_test_summary
    exit 1
fi

