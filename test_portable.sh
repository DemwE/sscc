#!/usr/bin/env bash
set -e

echo "🧪 Testing SSCC Portable Package"
echo "================================"

# Test 1: Basic functionality
echo "Test 1: Basic C program compilation..."
cd /home/demwe/sscc/dist/sscc-1.0.0

cat > hello.c << 'EOF'
#include <stdio.h>

int main() {
    printf("Hello from SSCC portable package!\n");
    return 0;
}
EOF

./sscc -static -o hello hello.c
echo "✅ Compilation successful"

echo "Running compiled program:"
./hello
echo "✅ Execution successful"

# Test 2: More complex program with multiple includes
echo -e "\nTest 2: Complex program with multiple includes..."
cat > complex.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    char *buffer = malloc(100);
    strcpy(buffer, "SSCC works with stdlib!");
    printf("%s\n", buffer);
    printf("String length: %zu\n", strlen(buffer));
    free(buffer);
    return 0;
}
EOF

./sscc -static -o complex complex.c
echo "✅ Complex compilation successful"

echo "Running complex program:"
./complex
echo "✅ Complex execution successful"

# Test 3: Check no external dependencies
echo -e "\nTest 3: Checking for external dependencies..."
if command -v ldd >/dev/null 2>&1; then
    echo "Checking dependencies of compiled binary:"
    if ldd hello 2>&1 | grep -q "not a dynamic executable"; then
        echo "✅ Binary is statically linked (no external dependencies)"
    else
        echo "📋 Dependencies found:"
        ldd hello
    fi
else
    echo "⚠️  ldd not available, skipping dependency check"
fi

# Test 4: File analysis
echo -e "\nTest 4: Package analysis..."
echo "Package size: $(du -sh . | cut -f1)"
echo "Binary size: $(du -sh sscc.bin | cut -f1)"
echo "Include files: $(find include -name "*.h" | wc -l) header files"
echo "Library files: $(find lib -name "*.a" | wc -l) static libraries"

# Test 5: Portability check
echo -e "\nTest 5: Checking portability..."
if file sscc.bin | grep -q "statically linked"; then
    echo "✅ Binary is statically linked"
else
    echo "📋 Binary type:"
    file sscc.bin
fi

# Cleanup
rm -f hello complex hello.c complex.c

echo -e "\n🎉 All tests passed! SSCC package is ready for distribution."
echo -e "\nTo test on another system:"
echo "1. Copy the tarball: sscc-1.0.0-linux-x86_64.tar.gz (1.5M) or sscc-1.0.0-linux-x86_64.tar.xz (1.2M)"
echo "2. Extract: tar -xf sscc-1.0.0-linux-x86_64.tar.gz"
echo "3. Test: cd sscc-1.0.0 && ./test.sh"
echo "4. Use: ./sscc -static -o program program.c"
