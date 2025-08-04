#!/bin/bash

# SAI Website Test Suite (Public Access Only)
# Tests that can be run from any location without server access
# Usage: ./scripts/test-website.sh

set -e

# Configuration
WEBSITE_URL=${WEBSITE_URL:-"https://sai.altermundi.net"}
TIMEOUT=${TIMEOUT:-10}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    ((TESTS_RUN++))
    log_info "Testing: $test_name"
    
    local result
    result=$(eval "$test_command" 2>/dev/null || echo "")
    if [[ "$result" =~ $expected_pattern ]]; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name - Expected: $expected_pattern, Got: $result"
        return 1
    fi
}

echo "🧪 SAI Website Test Suite"
echo "========================="
echo "Website: $WEBSITE_URL"
echo "Timeout: ${TIMEOUT}s"
echo

# Website Accessibility
log_info "🌐 Testing Website Accessibility"
run_test "Spanish website responds (200)" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/' -o /dev/null" \
    "200"

run_test "English website responds (200)" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/index-en.html' -o /dev/null" \
    "200"

run_test "Background image accessible" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/images/wildfire-camera-2.jpeg' -o /dev/null" \
    "200"

echo

# Content Verification
log_info "📄 Testing Content"
run_test "Spanish title correct" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o '<title>[^<]*</title>'" \
    "Sistema de Alerta de Incendios"

run_test "English title correct" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/index-en.html' | grep -o '<title>[^<]*</title>'" \
    "Fire Alert System"

run_test "Form endpoint configured" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'data-api-endpoint=\"[^\"]*\"'" \
    "/api/submit-form"

run_test "YouTube video configured" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'youtube.com/embed/[^\"]*'" \
    "youtube.com/embed/bbmto6GVLh8"

run_test "GitHub link present" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'github.com[^\"]*'" \
    "github.com/altermundi"

echo

# Security
log_info "🔒 Testing Security"
run_test "HTTPS enforced" \
    "curl -s -I --connect-timeout $TIMEOUT 'http://sai.altermundi.net' | grep -c 'Location.*https'" \
    "1"

run_test "HSTS header present" \
    "curl -s -I --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'Strict-Transport-Security'" \
    "1"

echo

# Cleanup Verification
log_info "🧹 Testing Cleanup"
run_test "Old video pages removed (404)" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/video.html' -o /dev/null" \
    "404"

run_test "Test directory removed (404)" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/test/' -o /dev/null" \
    "404"

echo

# Summary
echo "📊 Test Results"
echo "==============="
echo "Tests run: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo
    log_success "🎉 All website tests passed!"
    exit 0
else
    echo
    log_error "❌ Some tests failed. Check the deployment."
    exit 1
fi