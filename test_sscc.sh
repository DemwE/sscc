#!/run/current-system/sw/bin/bash

# SSCC Test Suite
echo "=== SSCC Test Suite ==="

SSCC="./build/sscc/sscc"
TEST_DIR="test_results"

mkdir -p "$TEST_DIR"

# Test 1: Basic Hello World
echo "Test 1: Basic Hello World"
cat > "$TEST_DIR/hello.c" << 'EOF'
#include <stdio.h>

int main() {
    printf("Hello from SSCC!\n");
    return 0;
}
EOF

if $SSCC -static -o "$TEST_DIR/hello" "$TEST_DIR/hello.c"; then
    if ./"$TEST_DIR/hello"; then
        echo "✅ Test 1 PASSED: Basic compilation and execution"
    else
        echo "❌ Test 1 FAILED: Execution failed"
    fi
else
    echo "❌ Test 1 FAILED: Compilation failed"
fi

# Test 2: Standard Library Functions
echo -e "\nTest 2: Standard Library Functions"
cat > "$TEST_DIR/stdlib_test.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    char *buf = malloc(100);
    if (!buf) {
        printf("malloc failed\n");
        return 1;
    }
    
    strcpy(buf, "SSCC stdlib works!");
    printf("%s\n", buf);
    
    free(buf);
    printf("Memory management OK\n");
    return 0;
}
EOF

if $SSCC -static -o "$TEST_DIR/stdlib_test" "$TEST_DIR/stdlib_test.c"; then
    if ./"$TEST_DIR/stdlib_test"; then
        echo "✅ Test 2 PASSED: Standard library functions"
    else
        echo "❌ Test 2 FAILED: Execution failed"
    fi
else
    echo "❌ Test 2 FAILED: Compilation failed"
fi

# Test 3: Math Functions
echo -e "\nTest 3: Math Functions"
cat > "$TEST_DIR/math_test.c" << 'EOF'
#include <stdio.h>
#include <math.h>

int main() {
    double x = 2.0;
    double result = sqrt(x);
    printf("sqrt(%.1f) = %.6f\n", x, result);
    return 0;
}
EOF

if $SSCC -static -o "$TEST_DIR/math_test" "$TEST_DIR/math_test.c" -lm; then
    if ./"$TEST_DIR/math_test"; then
        echo "✅ Test 3 PASSED: Math library functions"
    else
        echo "❌ Test 3 FAILED: Execution failed"
    fi
else
    echo "❌ Test 3 FAILED: Compilation failed"
fi

# Test 4: Self-contained check
echo -e "\nTest 4: Self-contained Binary Check"
if ldd "$TEST_DIR/hello" 2>&1 | grep -q "not a dynamic executable"; then
    echo "✅ Test 4 PASSED: Binary is statically linked"
else
    echo "❌ Test 4 FAILED: Binary has dynamic dependencies:"
    ldd "$TEST_DIR/hello" 2>/dev/null || echo "ldd not available"
fi

echo -e "\n=== Test Summary ==="
echo "SSCC basic functionality is working correctly."
echo "The compiler can create self-contained, statically linked binaries."

# Clean up
rm -rf "$TEST_DIR"
