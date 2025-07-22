# SSCC - Self Sufficient C Compiler

A self-contained C compiler based on TCC (Tiny C Compiler) with integrated runtime libraries.

## Features

SSCC integrates:
- **TCC** - Fast, lightweight C compiler (v0.9.27)
- **musl** - Lightweight C standard library (v1.2.5)
- **GMP** - GNU Multiple Precision Arithmetic Library (v6.3.0)

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

# Get help and usage information
./build/sscc/sscc --help
./build/sscc/sscc -h        # Short form also works

# Run the compiled program
./hello
```

### Command Line Options

SSCC supports all standard TCC options plus the following helpful commands:

```bash
# Display comprehensive help
./build/sscc/sscc --help

# Show version information
./build/sscc/sscc --version

# Enable debugging info
./build/sscc/sscc -g -o debug_program program.c

# Add include paths
./build/sscc/sscc -I/path/to/headers -o program program.c

# Link with specific libraries (already includes musl and GMP)
./build/sscc/sscc -lm -o math_program math_program.c
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

**Output:**
```
Hello from SSCC!
```

#### Mathematical Example with GMP

```c
#include <stdio.h>
#include <gmp.h>

int main() {
    mpz_t big_number;
    mpz_init(big_number);
    
    // Calculate 2^100
    mpz_ui_pow_ui(big_number, 2, 100);
    
    printf("2^100 = ");
    mpz_out_str(stdout, 10, big_number);
    printf("\n");
    
    mpz_clear(big_number);
    return 0;
}
```

Compile and run:
```bash
./build/sscc/sscc -static -o bigmath bigmath.c
./bigmath
```

### Features Working

- ✅ Complete C compiler with musl libc integration
- ✅ Static linking support  
- ✅ Self-contained binary (no external dependencies)
- ✅ Standard C library functions (stdio, stdlib, string, etc.)
- ✅ GMP library integration for arbitrary precision arithmetic
- ✅ Portable packaging (no system dependencies)
- ✅ Proper newline handling in printf statements
- ✅ Clean compilation (no implicit declaration warnings)
- ✅ Comprehensive help system (`--help`, `-h` flags)
- ✅ Cross-distribution compatibility

### Current Status

- ✅ All core functionality working
- ✅ All known issues fixed
- ✅ Complete development environment available
- ✅ Ready for distribution and production use

## Project Status

### Version Information

- **SSCC Version**: 1.0.0
- **TCC Version**: 0.9.27
- **musl Version**: 1.2.5  
- **GMP Version**: 6.3.0
- **Target Platform**: Linux x86_64

### Recent Fixes and Improvements

This version includes several important fixes and enhancements:

#### Fixed Issues ✅
1. **Newline Processing**: Fixed `\n` in printf statements to output actual newlines instead of literal "\n" strings
2. **Implicit Declarations**: Eliminated compiler warnings by ensuring proper header includes (`#include <stdio.h>`)
3. **Help System**: Implemented comprehensive `--help` and `-h` flag support with detailed usage information
4. **Build Environment**: Enhanced Nix development shell with all necessary dependencies
5. **Cross-Platform**: Improved package portability across different Linux distributions

#### Enhanced Features ✅
- **Better Documentation**: Comprehensive README with examples and troubleshooting
- **Improved Test Coverage**: Enhanced test scripts with proper verification
- **Development Tools**: Complete Nix-based development environment
- **Package Quality**: Better error handling and user experience

### Quality Assurance

- ✅ All core functionality tested and working
- ✅ Package installation verified on multiple systems
- ✅ No known compilation issues
- ✅ Complete dependency resolution
- ✅ Comprehensive test suite included

### Contributing

SSCC is a stable, self-contained C compiler suitable for:
- Embedded development
- Portable C compilation
- Educational purposes
- Systems where installing a full toolchain is impractical
- Quick C prototyping and testing

The project maintains compatibility with standard C while providing enhanced portability and ease of use.

## Building

### With Nix (Recommended)

The project includes a complete Nix development environment with all necessary dependencies:

```bash
# Enter the development shell
nix-shell

# Build the project
make

# The shell provides:
# - GCC, Make, autotools
# - All required build dependencies (m4, texinfo, flex, bison, etc.)
# - Optimized build environment
# - Automatic PATH and environment setup
```

### Traditional Build

Requirements:
- GCC compiler
- Make
- wget or curl
- autotools (autoconf, automake, libtool)
- Standard build tools: m4, texinfo, flex, bison
- Optional: upx (for binary compression)

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

## Development

### Development Environment

For development, use the Nix shell which provides a complete, reproducible build environment:

```bash
# Enter development shell
nix-shell

# The shell automatically sets up:
# - All build dependencies
# - Optimized compiler flags  
# - Proper environment variables
# - Development tools
```

### Testing Changes

```bash
# Build and test in one command
make test

# Build, package, and test the portable distribution
make test-package

# Clean build artifacts
make clean

# Clean everything including downloads
make distclean
```

### Troubleshooting

**Build Issues:**
- Ensure all dependencies are installed (use `nix-shell` for guaranteed environment)
- Check that you have sufficient disk space (~500MB for build)
- Verify internet connection for source downloads

**Runtime Issues:**
- Use `-static` flag for maximum portability
- Include `#include <stdio.h>` for printf and other standard functions
- GMP functions require `#include <gmp.h>`

**Packaging Issues:**
- Verify UPX is available for binary compression
- Check that the test script runs successfully with `make test-package`

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
- `dist/sscc-VERSION/` - Portable directory with all files
- `dist/sscc-VERSION-linux-x86_64.tar.gz` - Gzip compressed (1.5MB)
- `dist/sscc-VERSION-linux-x86_64.tar.xz` - XZ compressed (1.2MB)

### Testing on Other Systems

The portable package includes a test script:

```bash
# Extract the package
tar -xf sscc-VERSION-linux-x86_64.tar.gz
cd sscc-VERSION

# Run built-in test
./test.sh

# Manual usage
./sscc -static -o hello hello.c
./hello
```

### Package Contents

The portable package (`dist/sscc-VERSION/`) contains:
- `sscc` - Portable wrapper script (uses `#!/usr/bin/env bash`)
- `sscc.bin` - TCC compiler binary (164KB, statically linked)
- `include/` - 219 C standard library headers (musl + GMP)
- `lib/tcc/` - 11 static libraries (musl, GMP, TCC runtime)
- `test.sh` - Automated test script
- `README.txt` - Usage instructions

**Total size: 6.2MB uncompressed, 1.2MB compressed**

The package is completely self-contained with no system dependencies.

## Architecture

SSCC consists of several key components working together:

### Core Components

- **`sscc`** - Intelligent wrapper script that:
  - Detects the correct TCC binary location
  - Sets up include and library paths automatically  
  - Provides help and version information
  - Handles command-line argument forwarding
  - Supports both `--help` and `-h` flags
  
- **`sscc.bin`** - The actual TCC compiler binary:
  - Based on TCC v0.9.27
  - Statically linked with musl libc
  - No external dependencies
  - ~164KB optimized size
  
- **`include/`** - Complete header collection:
  - 219 C standard library headers from musl
  - GMP headers for arbitrary precision math
  - All headers needed for self-contained compilation
  
- **`lib/tcc/`** - Static library collection:
  - musl C library (libc, libm, libpthread, etc.)
  - GMP library (libgmp)
  - TCC runtime libraries
  - 11 libraries total for complete functionality

### How It Works

1. The `sscc` wrapper script detects its installation location
2. It automatically configures include paths (`-I`) and library paths (`-L`)
3. It invokes `sscc.bin` (TCC) with the correct arguments
4. TCC compiles the source code using the bundled headers and libraries
5. The result is a fully compiled binary with no external dependencies

### Package Structure

```
sscc-VERSION/
├── sscc           # Portable wrapper script (bash)
├── sscc.bin       # TCC compiler binary (statically linked)
├── include/       # 219 header files (musl + GMP)
├── lib/tcc/       # 11 static libraries  
├── test.sh        # Automated test script
└── README.txt     # Usage instructions
```

The wrapper script ensures the compiler finds all necessary headers and libraries without requiring environment variable configuration or system-wide installation.