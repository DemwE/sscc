#!/bin/bash
# SSCC Test Suite
# Comprehensive tests for SSCC functionality

set -euo pipefail

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SSCC_PATH="./build/sscc/sscc"
TEST_DIR="/tmp/sscc_test_$$"
TESTS_PASSED=0
TESTS_FAILED=0

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Setup test environment
setup_tests() {
    log "Setting up test environment..."
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Copy SSCC and addons to test directory
    cp -r "$(dirname "$SSCC_PATH")"/* .
    
    if [ ! -x "./sscc" ]; then
        fail "SSCC binary not found or not executable"
        exit 1
    fi
}

# Test basic compilation
test_basic_compilation() {
    log "Testing basic C compilation..."
    
    cat > hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from SSCC!\n");
    return 42;
}
EOF
    
    if ./sscc -o hello hello.c; then
        if ./hello && [ $? -eq 42 ]; then
            success "Basic compilation and execution"
        else
            fail "Program execution failed"
        fi
    else
        fail "Basic compilation failed"
    fi
}

# Test standard library functions
test_stdlib() {
    log "Testing standard library functions..."
    
    cat > stdlib_test.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int main() {
    // Test malloc/free
    char *ptr = malloc(100);
    if (!ptr) return 1;
    strcpy(ptr, "Memory test");
    printf("String: %s\n", ptr);
    free(ptr);
    
    // Test math functions
    double result = sqrt(16.0);
    printf("sqrt(16) = %.1f\n", result);
    
    if (result == 4.0) {
        printf("Standard library test passed\n");
        return 0;
    }
    return 1;
}
EOF
    
    if ./sscc -o stdlib_test stdlib_test.c -lm; then
        if ./stdlib_test; then
            success "Standard library functions"
        else
            fail "Standard library execution failed"
        fi
    else
        fail "Standard library compilation failed"
    fi
}

# Test optimization flags
test_optimization() {
    log "Testing optimization flags..."
    
    cat > opt_test.c << 'EOF'
#include <stdio.h>
int main() {
    int sum = 0;
    for(int i = 0; i < 1000; i++) {
        sum += i;
    }
    printf("Sum: %d\n", sum);
    return 0;
}
EOF
    
    if ./sscc -O2 -o opt_test opt_test.c; then
        if ./opt_test; then
            success "Optimization flags"
        else
            fail "Optimized program execution failed"
        fi
    else
        fail "Optimization compilation failed"
    fi
}

# Test debugging info
test_debug_info() {
    log "Testing debug information..."
    
    if ./sscc -g -o debug_test hello.c; then
        success "Debug information generation"
    else
        fail "Debug information compilation failed"
    fi
}

# Test addon system
test_addon_system() {
    log "Testing addon system..."
    
    # Test addon listing
    if ./sscc --list-addons >/dev/null 2>&1; then
        success "Addon listing functionality"
    else
        fail "Addon listing failed"
    fi
    
    # Test GMP addon if available
    if [ -f "sscc-gmp.addon" ]; then
        log "Testing GMP addon..."
        
        cat > gmp_test.c << 'EOF'
#include <stdio.h>
#include <gmp.h>

int main() {
    mpz_t big_num;
    mpz_init(big_num);
    mpz_set_ui(big_num, 2);
    mpz_pow_ui(big_num, big_num, 100);
    
    printf("2^100 = ");
    mpz_out_str(stdout, 10, big_num);
    printf("\n");
    
    mpz_clear(big_num);
    return 0;
}
EOF
        
        if ./sscc --addon sscc-gmp.addon -o gmp_test gmp_test.c -lgmp; then
            if ./gmp_test | grep -q "2^100"; then
                success "GMP addon functionality"
            else
                fail "GMP addon execution failed"
            fi
        else
            fail "GMP addon compilation failed"
        fi
    else
        warning "GMP addon not found, skipping GMP tests"
    fi
    
    # Test libextra addon if available
    if [ -f "sscc-libextra.addon" ]; then
        log "Testing libextra addon..."
        
        cat > libextra_test.c << 'EOF'
#include <stdio.h>
#include <pthread.h>
#include <sys/socket.h>

int main() {
    printf("Testing libextra headers:\n");
    printf("- pthread.h: Available\n");
    printf("- sys/socket.h: Available\n");
    printf("Libextra addon working!\n");
    return 0;
}
EOF
        
        if ./sscc --addon sscc-libextra.addon -o libextra_test libextra_test.c -lpthread; then
            if ./libextra_test; then
                success "Libextra addon functionality"
            else
                fail "Libextra addon execution failed"
            fi
        else
            fail "Libextra addon compilation failed"
        fi
    else
        warning "Libextra addon not found, skipping libextra tests"
    fi
}

# Test static linking
test_static_linking() {
    log "Testing static linking..."
    
    if ./sscc -static -o static_test hello.c; then
        # Check if the binary is statically linked
        if ! ldd static_test 2>/dev/null | grep -q "dynamically"; then
            success "Static linking"
        else
            fail "Binary is not statically linked"
        fi
    else
        fail "Static linking compilation failed"
    fi
}

# Test help and version
test_help_version() {
    log "Testing help and version..."
    
    if ./sscc --help >/dev/null 2>&1; then
        success "Help command"
    else
        fail "Help command failed"
    fi
    
    if ./sscc -v >/dev/null 2>&1 || ./sscc --version >/dev/null 2>&1; then
        success "Version command"
    else
        warning "Version command not available (normal for TCC)"
    fi
}

# Cleanup test environment
cleanup_tests() {
    log "Cleaning up test environment..."
    cd /
    rm -rf "$TEST_DIR"
}

# Show test results
show_results() {
    echo
    echo "🧪 Test Results"
    echo "==============="
    echo "✅ Passed: $TESTS_PASSED"
    echo "❌ Failed: $TESTS_FAILED"
    echo "📊 Total:  $((TESTS_PASSED + TESTS_FAILED))"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}💥 Some tests failed!${NC}"
        return 1
    fi
}

# Main test execution
main() {
    echo "🧪 SSCC Test Suite"
    echo "=================="
    echo
    
    # Check if SSCC is built
    if [ ! -f "$SSCC_PATH" ]; then
        fail "SSCC not found at $SSCC_PATH. Run 'make' or './build_dist.sh' first."
        exit 1
    fi
    
    setup_tests
    
    test_basic_compilation
    test_stdlib
    test_optimization
    test_debug_info
    test_addon_system
    test_static_linking
    test_help_version
    
    cleanup_tests
    show_results
}

# Handle script interruption
trap 'cleanup_tests; exit 1' INT TERM

# Run tests
main "$@"
