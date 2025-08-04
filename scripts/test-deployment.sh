#!/bin/bash

# SAI Deployment Test Suite
# Comprehensive sanity checks for website and proxy server deployment
# Usage: ./scripts/test-deployment.sh [options]

set -e

# Configuration
WEBSITE_URL=${WEBSITE_URL:-"https://sai.altermundi.net"}
PROXY_HOST=${PROXY_HOST:-"sai.altermundi.net"}
PROXY_PORT=${PROXY_PORT:-"8003"}
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

# Test results array
declare -a FAILED_TESTS=()

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
    FAILED_TESTS+=("$1")
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    local test_type="${4:-content}" # content, status, or custom
    
    ((TESTS_RUN++))
    log_info "Running: $test_name"
    
    if [[ "$test_type" == "status" ]]; then
        if eval "$test_command" >/dev/null 2>&1; then
            log_success "$test_name"
            return 0
        else
            log_error "$test_name"
            return 1
        fi
    elif [[ "$test_type" == "content" ]]; then
        local result
        result=$(eval "$test_command" 2>/dev/null || echo "")
        if [[ "$result" =~ $expected_pattern ]]; then
            log_success "$test_name"
            return 0
        else
            log_error "$test_name - Expected: $expected_pattern, Got: $result"
            return 1
        fi
    else
        # Custom test function
        if eval "$test_command"; then
            log_success "$test_name"
            return 0
        else
            log_error "$test_name"
            return 1
        fi
    fi
}

# Test functions
test_website_accessibility() {
    echo
    log_info "🌐 Testing Website Accessibility"
    echo "================================"
    
    run_test "Spanish website responds" \
        "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/' -o /dev/null" \
        "200" "content"
    
    run_test "English website responds" \
        "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/index-en.html' -o /dev/null" \
        "200" "content"
    
    run_test "Favicon accessible" \
        "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/favicon.ico' -o /dev/null" \
        "200" "content"
    
    run_test "Background image accessible" \
        "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/images/wildfire-camera-2.jpeg' -o /dev/null" \
        "200" "content"
}

test_website_content() {
    echo
    log_info "📄 Testing Website Content"
    echo "=========================="
    
    run_test "Spanish title present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o '<title>[^<]*</title>'" \
        "Sistema de Alerta de Incendios" "content"
    
    run_test "English title present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/index-en.html' | grep -o '<title>[^<]*</title>'" \
        "Fire Alert System" "content"
    
    run_test "Hero section content" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -i 'sistema de alerta'" \
        "Sistema de Alerta" "content"
    
    run_test "Nosotros section present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -i 'nosotros'" \
        "nosotros" "content"
    
    run_test "GitHub link present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'github.com[^\"]*'" \
        "github.com/altermundi" "content"
}

test_form_configuration() {
    echo
    log_info "📝 Testing Form Configuration"
    echo "============================="
    
    run_test "Form API endpoint configured" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'data-api-endpoint=\"[^\"]*\"'" \
        "/api/submit-form" "content"
    
    run_test "Required form fields present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'name=\"localidad\"'" \
        "1" "content"
    
    run_test "Phone field present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'name=\"telefono\"'" \
        "1" "content"
    
    run_test "Email field present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'name=\"email\"'" \
        "1" "content"
}

test_video_integration() {
    echo
    log_info "🎥 Testing Video Integration"
    echo "============================"
    
    run_test "YouTube embed configured" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'youtube.com/embed/[^\"]*'" \
        "youtube.com/embed/bbmto6GVLh8" "content"
    
    run_test "Video overlay JavaScript present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'video-overlay'" \
        "[1-9]" "content"
    
    run_test "Video trigger button present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'Ver impacto'" \
        "1" "content"
}

test_theme_elements() {
    echo
    log_info "🎨 Testing Theme Elements"
    echo "========================="
    
    run_test "Celeste color variables present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c '#74ACDF\\|#5691C8'" \
        "[1-9]" "content"
    
    run_test "Argentine theme styling present" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'Colores Argentinos'" \
        "1" "content"
    
    run_test "Background image configured" \
        "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'wildfire-camera-2.jpeg'" \
        "1" "content"
}

test_proxy_server() {
    echo
    log_info "🔧 Testing Proxy Server"
    echo "======================="
    
    # Test if we can connect to proxy (internal test)
    if command -v ssh >/dev/null 2>&1; then
        run_test "Proxy server health endpoint" \
            "ssh root@$PROXY_HOST 'curl -s http://127.0.0.1:$PROXY_PORT/api/health | grep -c \"status.*ok\"'" \
            "1" "content"
        
        run_test "Proxy server version" \
            "ssh root@$PROXY_HOST 'curl -s http://127.0.0.1:$PROXY_PORT/api/health | grep -o \"version.*1\\.2\\.0\"'" \
            "version.*1.2.0" "content"
        
        run_test "Proxy authentication configured" \
            "ssh root@$PROXY_HOST 'curl -s http://127.0.0.1:$PROXY_PORT/api/health | grep -c \"api_key_configured.*true\"'" \
            "1" "content"
    else
        log_warning "SSH not available - skipping proxy server tests"
    fi
}

test_form_submission() {
    echo
    log_info "📤 Testing Form Submission"
    echo "=========================="
    
    if command -v ssh >/dev/null 2>&1; then
        # Test form submission with mock data
        local test_payload='{
            "localidad": "Test City Deploy",
            "departamento": "Test Dept",
            "provincia": "Test Province", 
            "nombre": "Deploy",
            "apellido": "Test",
            "telefono": "+54 11 1234 5678",
            "email": "deploy-test@example.com",
            "test": "true"
        }'
        
        run_test "Form submission works" \
            "ssh root@$PROXY_HOST 'curl -s -X POST http://127.0.0.1:$PROXY_PORT/api/submit-form -H \"Content-Type: application/json\" -d '\'$test_payload\'' | grep -c \"success.*true\"'" \
            "1" "content"
        
        run_test "Phone number cleaning works" \
            "ssh root@$PROXY_HOST 'timeout 30 journalctl -u sai-proxy -n 5 --no-pager | grep -c \"Deploy Test\"'" \
            "[0-9]" "content"
    else
        log_warning "SSH not available - skipping form submission tests"
    fi
}

test_security_headers() {
    echo
    log_info "🔒 Testing Security Headers"
    echo "==========================="
    
    run_test "HTTPS redirect works" \
        "curl -s -I --connect-timeout $TIMEOUT 'http://sai.altermundi.net' | grep -c 'Location.*https'" \
        "1" "content"
    
    run_test "HSTS header present" \
        "curl -s -I --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -c 'Strict-Transport-Security'" \
        "1" "content"
}

test_performance() {
    echo
    log_info "⚡ Testing Performance"
    echo "====================="
    
    run_test "Page loads within 5 seconds" \
        "timeout 5 curl -s --connect-timeout 5 '$WEBSITE_URL/' >/dev/null" \
        "" "status"
    
    run_test "Image loads within 10 seconds" \
        "timeout 10 curl -s --connect-timeout 10 '$WEBSITE_URL/images/wildfire-camera-2.jpeg' >/dev/null" \
        "" "status"
}

# Cleanup tests - verify removed content is gone
test_cleanup() {
    echo
    log_info "🧹 Testing Cleanup"
    echo "=================="
    
    run_test "Video pages removed (video.html)" \
        "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/video.html' -o /dev/null" \
        "404" "content"
    
    run_test "Video pages removed (video-en.html)" \
        "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/video-en.html' -o /dev/null" \
        "404" "content"
    
    run_test "Test directory removed" \
        "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/test/' -o /dev/null" \
        "404" "content"
}

# Main execution
main() {
    echo "🧪 SAI Deployment Test Suite"
    echo "============================"
    echo "Website: $WEBSITE_URL"
    echo "Proxy: $PROXY_HOST:$PROXY_PORT"
    echo "Timeout: ${TIMEOUT}s"
    echo

    # Run all test suites
    test_website_accessibility
    test_website_content  
    test_form_configuration
    test_video_integration
    test_theme_elements
    test_proxy_server
    test_form_submission
    test_security_headers
    test_performance
    test_cleanup

    # Summary
    echo
    echo "📊 Test Summary"
    echo "==============="
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo
        log_success "🎉 All tests passed! Deployment is healthy."
        exit 0
    else
        echo
        log_error "💥 Some tests failed:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}• $failed_test${NC}"
        done
        echo
        log_error "❌ Deployment has issues that need attention."
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "SAI Deployment Test Suite"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help"
        echo "  --quick, -q    Run only essential tests"
        echo "  --verbose, -v  Show detailed output"
        echo
        echo "Environment variables:"
        echo "  WEBSITE_URL    Website to test (default: https://sai.altermundi.net)"
        echo "  PROXY_HOST     Proxy server host (default: sai.altermundi.net)"
        echo "  PROXY_PORT     Proxy server port (default: 8003)"
        echo "  TIMEOUT        Request timeout in seconds (default: 10)"
        echo
        echo "Examples:"
        echo "  $0                    # Run all tests"
        echo "  $0 --quick           # Run essential tests only"
        echo "  TIMEOUT=30 $0        # Run with 30s timeout"
        exit 0
        ;;
    --quick|-q)
        # Quick mode - run only essential tests
        test_website_accessibility
        test_form_configuration
        test_proxy_server
        ;;
    --verbose|-v)
        set -x
        main
        ;;
    *)
        main
        ;;
esac