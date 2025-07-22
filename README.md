# SSCC - Self Sufficient C Compiler

A truly portable, self-contained C compiler based on TCC (Tiny C Compiler) with complete POSIX functionality, advanced RAM filesystem support, and addon system. SSCC creates a single executable that contains everything needed to compile C programs with blazing-fast performance using pure memory storage.

## 🌟 Key Features

- **🔥 Single Executable**: Everything embedded in one binary - no external dependencies
- **⚡ Fast Compilation**: Based on TCC for lightning-fast compile times
- **📦 Complete Core**: Full POSIX functionality built-in + optional addons
- **🚀 Portable**: Works on any Linux system without installation
- **💾 Retro-Friendly**: Core fits in ~600KB for ultimate portability
- **🎯 Static Linking**: All outputs are statically linked for true portability
- **🧠 Smart Addons**: Dynamic core detection prevents file duplication

## 📋 What's Included

### Core Components (Always Available)
- **TCC v0.9.27** - Fast, lightweight C compiler with embedded binary
- **musl v1.2.5** - Complete lightweight C standard library with full POSIX support
- **RAM Filesystem** - Advanced memory storage with priority fallbacks
- **Complete headers**: All standard headers including stdio.h, stdlib.h, string.h, math.h, stdint.h, bits/*.h, etc.
- **Full libraries**: Complete musl libc.a, libm.a, libtcc1.a, and all POSIX libraries
- **Memory Tracking**: Real-time RAM usage monitoring

### RAM Filesystem Technology
SSCC uses an intelligent RAM filesystem with priority fallback:

1. **memfd_create()** (Primary) - Pure memory files, no disk I/O
2. **/dev/shm** (Secondary) - Shared memory filesystem
3. **Disk /tmp** (Fallback) - Traditional temporary directory

### Dynamic Core Detection
SSCC v1.2.0 introduces intelligent addon management:

- **Automatic exclusion**: Addons automatically detect and exclude core files already embedded in SSCC
- **No duplication**: Prevents duplicate headers/libraries between core and addons
- **Optimal size**: Addons only contain additional functionality not in core
- **Smart loading**: Runtime reads embedded core data to determine exclusions

### Optional Addons
- **sscc-gmp.addon** - GNU Multiple Precision Arithmetic Library for advanced mathematical operations

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
Created memory filesystem using memfd_create: /tmp/sscc_memfd_2225819
SSCC - Modular C Compiler
Loading core 'musl': Complete C standard library (228 files)
Core 'musl' loaded: 510.80 KB in RAM
Total cached size: 892.52 KB (memfd)
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
#include <stdint.h>

int main() {
    uint32_t answer = 42;
    printf("Hello from SSCC! Answer: %u\n", answer);
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
make dist        # Create distribution build
make compressed  # Create compressed archives
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
- `make dist` - Create distribution build
- `make compressed` - Create compressed archives
- `make package` - Create distribution package (alias for dist)
- `make clean` - Clean build artifacts
- `make distclean` - Clean everything including downloads

## 📦 Distribution Packages

After building, you'll find:

```
dist/sscc/
├── sscc                   # Self-contained executable (326K - core + TCC embedded)
└── sscc-gmp.addon         # GMP math library addon (260K)
```

## 🎯 Architecture

### Self-Contained Design with RAM Filesystem
```
┌──────────────────────────────────────────────────────────┐
│                    sscc (564K main)                      │
│  ┌─────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │ Embedded    │ │ Complete Core   │ │ RAM Filesystem  │ │
│  │ TCC Binary  │ │ Resources       │ │ Manager         │ │
│  │ (390KB)     │ │ • All Headers   │ │ • memfd_create  │ │
│  │             │ │ • All Libraries │ │ • /dev/shm      │ │
│  │             │ │ • Full POSIX    │ │ • Fallbacks     │ │
│  │             │ │ • 228 files     │ │ • Auto cleanup  │ │
│  └─────────────┘ └─────────────────┘ └─────────────────┘ │
└──────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│                Runtime Process                           │
│  1. Create RAM filesystem (memfd/shm/disk)               │
│  2. Extract TCC binary to memory                         │
│  3. Extract complete musl headers/libs to memory         │
│  4. Load available .addon files with dynamic filtering   │
│  5. Execute TCC with memory-based paths                  │
│  6. Track RAM usage and cleanup automatically            │
└──────────────────────────────────────────────────────────┘
```

### Addon System with Dynamic Core Detection
- **Explicit loading**: `--addon filename.addon`
- **Smart exclusion**: Automatically excludes core files from addons
- **Compressed**: Uses LZMA compression for optimal file sizes
- **Modular**: Only load what you need

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
| sscc (complete) | 326KB | Complete compiler with embedded TCC + full musl (228 files) |
| sscc-gmp.addon | 260KB | GMP math library addon with smart core exclusion |
| **Total with GMP** | **586KB** | **Full-featured development environment** |

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
- Note: Basic math functions are included in core, GMP needed only for arbitrary precision

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
