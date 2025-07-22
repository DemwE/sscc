# SSCC - Self Sufficient C Compiler

A self-contained C compiler based on TCC (Tiny C Compiler) with integrated runtime libraries and modular addon support.

## Features

SSCC integrates:
- **TCC** - Fast, lightweight C compiler (v0.9.27)
- **musl** - Lightweight C standard library (v1.2.5)
- **GMP** - GNU Multiple Precision Arithmetic Library (v6.3.0)

The resulting compiler is self-contained and can compile C programs without requiring external libraries or headers. It supports a modular addon system for optional functionality.

## Basic Usage

Once built, SSCC is a self-contained C compiler that can be used just like any other C compiler:

```bash
# Compile a simple program
./build/sscc/sscc -o hello hello.c

# Compile with optimization
./build/sscc/sscc -O2 -o hello hello.c

# Get help and usage information
./build/sscc/sscc --help

# Use addon functionality
./build/sscc/sscc --addon sscc-gmp.addon -o math math.c -lgmp

# Run the compiled program
./hello
```

## Addon System

SSCC supports modular addons for optional functionality:

```bash
# List available addons
./build/sscc/sscc --list-addons

# Load specific addon
./build/sscc/sscc --addon filename.addon [options] file.c

# Auto-discovery of addons
# Place *.addon files in current directory for automatic loading
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
./build/sscc/sscc -o math_program math_program.c -lgmp
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
./build/sscc/sscc -o hello hello.c
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
./build/sscc/sscc -o bigmath bigmath.c -lgmp
./bigmath
```

**Note:** When using GMP functions, you must include the `-lgmp` flag to link with the GMP library. All binaries are statically linked by default for maximum portability.

### Current Status

- ✅ Self-contained C compiler
- ✅ Static linking by default for portability  
- ✅ Integrated musl libc and GMP libraries
- ✅ Modular addon system
- ✅ Auto-discovery of addon files
- ✅ Complete development environment available
- ✅ Cross-distribution compatibility

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
6. Generate addon files for modular deployment

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

### Testing

```bash
# Build and test
make test

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
- All binaries are statically linked by default for maximum portability
- Include `#include <stdio.h>` for printf and other standard functions
- GMP functions require `#include <gmp.h>` AND `-lgmp` linking flag
- For undefined GMP symbols, ensure you're using `-lgmp` when compiling

**Packaging Issues:**
- Verify UPX is available for binary compression
- Check that the test script runs successfully with `make test-package`

## Creating Portable Packages

To create a distributable package:

```bash
# Create portable package
make package

# Create compressed distribution archives
make dist
```

This creates:
- `dist/sscc-VERSION/` - Portable directory that can be copied anywhere
- `dist/sscc-VERSION-linux-x86_64.tar.gz` - Gzipped tarball for distribution
- `dist/sscc-VERSION-linux-x86_64.tar.xz` - Xz-compressed tarball (smaller)

The portable package is self-contained and works on any Linux system without dependencies.

### Testing on Another System

```bash
# Extract and test the package
tar -xzf sscc-VERSION-linux-x86_64.tar.gz
cd sscc-VERSION/

# Use the compiler
./sscc -o hello hello.c
```

## Architecture

SSCC consists of several key components:

### Core Components

- **`sscc`** - Main wrapper that handles addon loading and compilation setup
- **`sscc.bin`** - The TCC compiler binary (statically linked)
- **Core resources** - Essential C standard library headers and libraries
- **Addon system** - Modular extension mechanism for optional functionality

### Addon System

The addon system allows optional functionality to be loaded as needed:

- **Auto-discovery**: Automatically loads `*.addon` files in current directory
- **Explicit loading**: Use `--addon filename.addon` for specific requirements
- **Modular**: Only include functionality you need