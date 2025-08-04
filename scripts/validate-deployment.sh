#!/bin/bash

# SAI Deployment Validation Script
# Quick and reliable deployment sanity checks
# Usage: ./scripts/validate-deployment.sh

WEBSITE_URL=${WEBSITE_URL:-"https://sai.altermundi.net"}
TIMEOUT=5

echo "🔍 SAI Deployment Validation"
echo "============================"
echo "Website: $WEBSITE_URL"
echo

# Test counter
PASSED=0
FAILED=0

run_check() {
    local name="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "🔄 $name... "
    
    if result=$(timeout $TIMEOUT bash -c "$command" 2>/dev/null); then
        if [[ "$result" =~ $expected ]]; then
            echo "✅ PASS"
            ((PASSED++))
        else
            echo "❌ FAIL (got: $result)"
            ((FAILED++))
        fi
    else
        echo "❌ FAIL (timeout/error)"
        ((FAILED++))
    fi
}

# Core functionality tests
run_check "Spanish website responds" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/' -o /dev/null" \
    "200"

run_check "English website responds" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/index-en.html' -o /dev/null" \
    "200"

run_check "Background image accessible" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/images/wildfire-camera-2.jpeg' -o /dev/null" \
    "200"

run_check "Spanish title correct" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'Sistema de Alerta de Incendios'" \
    "Sistema de Alerta de Incendios"

run_check "Form endpoint configured" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o '/api/submit-form'" \
    "/api/submit-form"

run_check "Video integration present" \
    "curl -s --connect-timeout $TIMEOUT '$WEBSITE_URL/' | grep -o 'youtube.com/embed/bbmto6GVLh8'" \
    "youtube.com/embed/bbmto6GVLh8"

run_check "Old video pages removed" \
    "curl -s -w '%{http_code}' --connect-timeout $TIMEOUT '$WEBSITE_URL/video.html' -o /dev/null" \
    "404"

run_check "HTTPS enforced" \
    "curl -s -I --connect-timeout $TIMEOUT 'http://sai.altermundi.net' | grep -c 'Location.*https'" \
    "[1-9]"

echo
echo "📊 Results: $PASSED passed, $FAILED failed"

if [ $FAILED -eq 0 ]; then
    echo "🎉 All checks passed! Deployment is healthy."
    exit 0
else
    echo "⚠️  Some checks failed. Review deployment."
    exit 1
fi