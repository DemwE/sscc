# SSCC - Self Sufficient C Compiler

A self-contained C compiler based on TCC (Tiny C Compiler) with integrated runtime libraries.

## Features

SSCC integrates:
- **TCC** - Fast, lightweight C compiler
- **musl** - Lightweight C standard library
- **GMP** - GNU Multiple Precision Arithmetic Library (planned)

The resulting compiler is self-contained and can compile C programs without requiring external libraries or headers.

## Usage

Once built, SSCC is a self-contained C compiler that can be used just like any other C compiler:

```bash
# Compile a simple program
./build/sscc/sscc -o hello hello.c

# Compile with static linking (recommended)
./build/sscc/sscc -static -o hello hello.c

# Compile with optimization
./build/sscc/sscc -static -O2 -o hello hello.c

# Run the compiled program
./hello
```

### Example Programs

Create a simple Hello World program:
```c
#include <stdio.h>

int main() {
    printf("Hello from SSCC!\n");
    return 0;
}
```

Compile and run:
```bash
./build/sscc/sscc -static -o hello hello.c
./hello
```

### Features Working

- ✅ Complete C compiler with musl libc integration
- ✅ Static linking support  
- ✅ Self-contained binary (no external dependencies)
- ✅ Standard C library functions (stdio, stdlib, string, etc.)
- ✅ GMP library integration (math functions)
- ✅ Portable packaging (no system dependencies)

### Current Status

- All core functionality working
- Ready for distribution and testing

## Building

### With Nix (Recommended)

```bash
nix-shell
make
```

### Traditional Build

Requirements:
- GCC compiler
- Make
- wget or curl
- autotools
- upx (optional, for binary compression)

```bash
make
```

This will:
1. Download TCC, musl, and GMP source code
2. Build musl with static library support
3. Build GMP with static library support  
4. Build TCC with musl and GMP integration
5. Create a self-contained SSCC binary in `build/sscc/`
6. Strip debug symbols and compress with UPX (if available)

## Installation

```bash
make install PREFIX=/usr/local
```

Or simply copy the `build/sscc/` directory to your desired location.

## Creating Portable Packages

To create a distributable package that works on any Linux system without dependencies:

```bash
# Create portable package
make package

# Create compressed distribution archives
make dist

# Test the package
make test-package
```

This creates:
- `dist/sscc-VERSION/` - Portable directory that can be copied anywhere
- `dist/sscc-VERSION-linux-x86_64.tar.gz` - Gzipped tarball for distribution
- `dist/sscc-VERSION-linux-x86_64.tar.xz` - Xz-compressed tarball (smaller)

The portable package:
- ✅ Uses standard `/bin/bash` shebang (works on any Linux)
- ✅ Contains all necessary headers and libraries
- ✅ No external dependencies required
- ✅ Includes test script to verify functionality
- ✅ Complete package size: ~6MB

### Testing on Another System

```bash
# Extract and test the package
tar -xzf sscc-VERSION-linux-x86_64.tar.gz
cd sscc-VERSION/
./test.sh

# Use the compiler
./sscc -static -o hello hello.c
```

## Packaging and Distribution

SSCC can be packaged into a portable, self-contained distribution that works on any Linux system without dependencies.

### Creating a Portable Package

```bash
# Build and create portable package
make package

# Create compressed distribution archives
make dist

# Test the package
make test-package
```

This creates:
- `dist/sscc-1.0.0/` - Portable directory with all files
- `dist/sscc-1.0.0-linux-x86_64.tar.gz` - Gzip compressed (1.5MB)
- `dist/sscc-1.0.0-linux-x86_64.tar.xz` - XZ compressed (1.2MB)

### Testing on Other Systems

The portable package includes a test script:

```bash
# Extract the package
tar -xf sscc-1.0.0-linux-x86_64.tar.gz
cd sscc-1.0.0

# Run built-in test
./test.sh

# Manual usage
./sscc -static -o hello hello.c
./hello
```

### Package Contents

The portable package (`dist/sscc-1.0.0/`) contains:
- `sscc` - Portable wrapper script (uses `#!/usr/bin/env bash`)
- `sscc.bin` - TCC compiler binary (164KB, statically linked)
- `include/` - 219 C standard library headers (musl + GMP)
- `lib/tcc/` - 11 static libraries (musl, GMP, TCC runtime)
- `test.sh` - Automated test script
- `README.txt` - Usage instructions

**Total size: 6.2MB uncompressed, 1.2MB compressed**

The package is completely self-contained with no system dependencies.

## Architecture

SSCC consists of:
- `sscc` - Wrapper script that invokes TCC with correct paths
- `sscc.bin` - The actual TCC binary
- `include/` - Headers from musl and GMP
- `lib/tcc/` - Static libraries (musl, GMP, TCC runtime)

The wrapper script ensures the compiler finds all necessary headers and libraries without requiring environment variable configuration.