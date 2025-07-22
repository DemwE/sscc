# SSCC - Self Sufficient C Compiler

A truly portable, self-contained C compiler based on TCC (Tiny C Compiler) with integrated runtime libraries, advanced RAM filesystem support, and modular addon system. SSCC creates a single executable that contains everything needed to compile C programs with blazing-fast performance using pure memory storage.

## 🌟 Key Features

- **🔥 Single Executable**: Everything embedded in one binary - no external dependencies
- **⚡ Fast Compilation**: Based on TCC for lightning-fast compile times
- **📦 Modular Design**: Core functionality + optional addons as needed
- **🚀 Portable**: Works on any Linux system without installation
- **💾 Retro-Friendly**: Fits on a 1.44MB floppy disk for ultimate portability
- **🎯 Static Linking**: All outputs are statically linked for true portability

## 📋 What's Included

### Core Components (Always Available)
- **TCC v0.9.27** - Fast, lightweight C compiler with embedded binary
- **musl v1.2.5** - Lightweight C standard library  
- **RAM Filesystem** - Advanced memory storage with priority fallbacks
- **Essential headers**: stdio.h, stdlib.h, string.h, math.h, etc.
- **Core libraries**: libc.a, libm.a, libtcc1.a
- **Memory Tracking**: Real-time RAM usage monitoring

### RAM Filesystem Technology
SSCC uses an intelligent RAM filesystem with priority fallback:

1. **memfd_create()** (Primary) - Pure memory files, no disk I/O
2. **/dev/shm** (Secondary) - Shared memory filesystem
3. **Disk /tmp** (Fallback) - Traditional temporary directory

### Optional Addons
- **sscc-libextra.addon** - Extended musl libraries (POSIX, threading, networking)
- **sscc-gmp.addon** - GNU Multiple Precision Arithmetic Library

## 💻 Usage Examples

### Basic Compilation
```bash
# Simple program
./sscc -o program program.c

# With optimization
./sscc -O2 -o fast_program program.c

# With debugging info
./sscc -g -o debug_program program.c
```

### Example Output
```bash
$ ./sscc hello.c -o hello
Created memory filesystem using memfd_create: /tmp/sscc_memfd_12345
SSCC - Modular C Compiler
Extracting core: 15 files...
Extracting: include/assert.h -> memfd (428 bytes)
Extracting: include/stdlib.h -> memfd (4.76 KB)
Extracting: include/stddef.h -> memfd (547 bytes)
Extracting: include/stdbool.h -> memfd (167 bytes)
Extracting: include/stdint.h -> memfd (2.52 KB)
Extracting: include/stdio.h -> memfd (5.73 KB)
Extracting: include/math.h -> memfd (11.22 KB)
Extracting: include/features.h -> memfd (865 bytes)
Extracting: include/bits/syscall.h -> memfd (20.30 KB)
Extracting: include/bits/alltypes.h -> memfd (11.18 KB)
Extracting: include/stdarg.h -> memfd (351 bytes)
Extracting: include/errno.h -> memfd (369 bytes)
Extracting: include/string.h -> memfd (2.94 KB)
Extracting: lib/libtcc1.a -> memfd (48.14 KB)
Extracting: lib/libm.a -> memfd (8 bytes)
Extracting: tcc -> /tmp/sscc_memfd_12345/tcc (373.72 KB)
Libs cached size: 483.17 KB (memfd)
Starting compilation...

$ ./hello
Hello from SSCC!
```

### Using Addons
```bash
# Compile with GMP math library
./sscc --addon sscc-gmp.addon -o math math.c -lgmp
```

### Advanced Examples

**Simple Hello World:**
```c
#include <stdio.h>
int main() {
    printf("Hello from SSCC!
");
    return 0;
}
```

**Big Integer Math with GMP:**
```c
#include <stdio.h>
#include <gmp.h>

int main() {
    mpz_t result;
    mpz_init(result);
    
    // Calculate 2^1000
    mpz_ui_pow_ui(result, 2, 1000);
    
    printf("2^1000 = ");
    mpz_out_str(stdout, 10, result);
    printf("
");
    
    mpz_clear(result);
    return 0;
}
```

Compile: `./sscc --addon sscc-gmp.addon -o bigmath bigmath.c -lgmp`

## 🛠 Building from Source

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt install build-essential wget autoconf automake libtool m4 texinfo liblzma-dev

# Fedora/RHEL
sudo dnf install gcc make wget autoconf automake libtool m4 texinfo xz-devel

# Optional: for binary compression
sudo apt install upx  # or: sudo dnf install upx
```

### Build Options

**Option 1: Automated Build (Recommended)**
```bash
./build_dist.sh
```

**Option 2: Step-by-Step Build**
```bash
# Download dependencies
make deps

# Build individual components
make musl        # Build musl libc
make gmp         # Build GMP library  
make tcc         # Build TCC compiler
make sscc        # Create SSCC wrapper
make addons      # Create addon packages

# Create distribution
make floppy      # Portable package
make dist        # Compressed archives
```

**Option 3: With Nix (Reproducible)**
```bash
nix-shell        # Enter development environment
make             # Build with all dependencies available
```

### Build Targets
- `make` or `make all` - Build everything
- `make sscc` - Build core SSCC binary
- `make addons` - Create addon packages
- `make test` - Test the built compiler
- `make floppy` - Create portable package
- `make dist` - Create distribution archives
- `make diskette` - Create 1.44MB floppy disk image
- `make clean` - Clean build artifacts
- `make distclean` - Clean everything including downloads

## 📦 Distribution Packages

After building, you'll find:

```
dist/sscc-VERSION/
├── sscc                   # Self-contained executable (core + TCC embedded)
├── sscc-libextra.addon    # Extended libraries addon
└── sscc-gmp.addon         # GMP math library addon
```

## 🎯 Architecture

### Self-Contained Design with RAM Filesystem
```
┌──────────────────────────────────────────────────────────┐
│                    sscc (main)                           │
│  ┌─────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │ Embedded    │ │ Embedded Core   │ │ RAM Filesystem  │ │
│  │ TCC Binary  │ │ Resources       │ │ Manager         │ │
│  │ (373KB)     │ │ • Headers       │ │ • memfd_create  │ │
│  │             │ │ • Libraries     │ │ • /dev/shm      │ │
│  │             │ │ • Compressed    │ │ • Fallbacks     │ │
│  └─────────────┘ └─────────────────┘ └─────────────────┘ │
└──────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│                Runtime Process                           │
│  1. Create RAM filesystem (memfd/shm/disk)              │
│  2. Extract TCC binary to memory                        │
│  3. Extract core headers/libs to memory                 │
│  4. Load available .addon files                         │
│  5. Execute TCC with memory-based paths                 │
│  6. Track RAM usage and cleanup automatically           │
└──────────────────────────────────────────────────────────┘
```

### Addon System
- **Explicit loading**: `--addon filename.addon`
- **Compressed**: Uses LZMA compression for small file sizes
- **Modular**: Only load what you need

## 🧪 Testing

```bash
# Basic functionality test
make test

# Test portable package
make test-package

# Manual testing
echo 'int main(){return 42;}' | ./sscc -o test -
echo $?  # Should output: 42
```

## 📊 Size Comparison

| Component | Size | Description |
|-----------|------|-------------|
| sscc (self-contained) | ~200KB | Complete compiler with embedded TCC + core |
| sscc-libextra.addon | ~140KB | Extended POSIX libraries |
| sscc-gmp.addon | ~275KB | GMP math library |
| **With All Addons** | **~620KB** | **Full-featured development environment** |

*Compare to GCC: ~100MB+ with dependencies*

## 🔧 Troubleshooting

### Build Issues
```bash
# Check dependencies
./build_dist.sh  # Will check and report missing deps

# Clean build
make distclean && make

# Debug build failure
make V=1  # Verbose output
```

### Runtime Issues
```bash
# Check compiler
./sscc --help

# Test basic functionality  
echo 'int main(){return 0;}' | ./sscc -o test -

# Check available addons by looking for .addon files
ls *.addon 2>/dev/null || echo "No addon files found"
```

### Common Problems

**"No such file or directory" when running compiled programs:**
- SSCC uses static linking by default - binaries should be portable
- Check that compilation completed successfully

**"undefined reference" errors:**
- Include required libraries: `-lm` for math, `-lgmp` for GMP
- Load appropriate addon: `--addon sscc-gmp.addon` for GMP functions

**Slow compilation on older systems:**
- SSCC will automatically fall back to disk if RAM filesystem unavailable
- Check which mode: `./sscc ... 2>&1 | head -1` shows filesystem type
- memfd_create() requires Linux 3.17+, /dev/shm works on most systems

**Build failures:**
- Ensure all dependencies are installed
- Use `nix-shell` for guaranteed reproducible environment
- Check available disk space (need ~500MB for full build)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make changes and test: `make test`
4. Commit: `git commit -am 'Add feature'`
5. Push: `git push origin feature-name`
6. Create Pull Request

### Development Environment
```bash
# Enter development shell with all dependencies
nix-shell

# Or use Docker
docker run -v $(pwd):/src -w /src ubuntu:22.04 bash
apt update && apt install -y build-essential wget autoconf automake libtool m4 texinfo liblzma-dev
```

## 📄 License

SSCC itself is released under the MIT License. It incorporates:
- **TCC**: LGPL v2.1
- **musl**: MIT License  
- **GMP**: LGPL v3

See individual component licenses for details.

## 🔗 Links

- [TCC Official Site](https://bellard.org/tcc/)
- [musl libc](https://musl.libc.org/)
- [GMP Library](https://gmplib.org/)

---

**Made with ❤️ for portable C development**
