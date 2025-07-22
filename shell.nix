{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  name = "sscc-build-env";
  
  buildInputs = with pkgs; [
    # Core build tools
    gcc
    gnumake
    binutils

    # Other build tools
    flex
    bison
    zlib
    zlib.dev
    zlib.static
    xz
    xxd
    
    # Version control and download tools
    git
    wget
    curl
    
    # Archive extraction
    gnutar
    gzip
    xz
    bzip2
    
    # Development tools
    pkg-config
    autoconf
    automake
    libtool
    m4
    texinfo
    
    # Additional utilities
    file
    which
    coreutils
    findutils
    diffutils
    patch
    upx
    mtools
    
    # For testing and validation
    strace
    glibc.bin  # provides ldd
  ];
  
  shellHook = ''
    echo "🔧 SSCC Build Environment Ready!"
    echo "📦 Available tools:"
    echo "   • gcc $(gcc --version | head -1 | cut -d' ' -f4)"
    echo "   • make $(make --version | head -1 | cut -d' ' -f3)"
    echo "   • git $(git --version | cut -d' ' -f3)"
    echo "   • autotools $(autoconf --version | head -1 | cut -d' ' -f4)"
    echo "   • upx $(upx --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo 'available')"
    echo "   • zlib $(pkg-config --modversion zlib)"
    echo "   • lzma $(xz --version 2>/dev/null | head -1 | cut -d' ' -f4 || echo 'available')"
    echo "   • mtools $(mtools --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo 'available')"
    echo ""
    echo "🚀 To build SSCC:"
    echo "   make           # Build everything"
    echo "   make package   # Create portable package"
    echo "   make dist      # Create distribution archives"
    echo "   make floppy    # Create 1.44MB floppy package"
    echo "   make addons    # Create addon files"
    echo "   make help      # Show all available targets"
    echo ""
    echo "📁 Build outputs:"
    echo "   • Compiler: ./build/sscc/sscc"
    echo "   • Package:  ./dist/sscc-<version>/"
    echo ""
    
    # Set environment variables for reproducible builds
    export CC=gcc
    export CXX=g++
    export MAKE=make
    
    # Ensure proper temporary directory
    export TMPDIR=/tmp
    
    # Ensure proper library paths for static linking
    export PKG_CONFIG_PATH="${pkgs.zlib.dev}/lib/pkgconfig:${pkgs.zlib.static}/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LIBRARY_PATH="${pkgs.zlib.static}/lib:${pkgs.zlib}/lib:$LIBRARY_PATH"
    export LD_LIBRARY_PATH="${pkgs.zlib}/lib:$LD_LIBRARY_PATH"
    export C_INCLUDE_PATH="${pkgs.zlib.dev}/include:$C_INCLUDE_PATH"
    
    # Ensure proper paths for built tools
    export PATH="$PWD/build/sscc:$PWD/build/musl/bin:$PWD/build/gmp/bin:$PATH"
    
    # Set build flags for consistent compilation
    export CFLAGS="-O2 -fPIC"
    export LDFLAGS="-static"
    
    # Create .envrc for direnv users
    if command -v direnv >/dev/null 2>&1; then
      if [ ! -f .envrc ]; then
        echo "use nix" > .envrc
        echo "💡 Created .envrc for direnv. Run 'direnv allow' to auto-enter this shell."
      fi
    fi
    
    # Quick validation that we can build
    if [ ! -f "Makefile" ]; then
      echo "⚠️  Warning: No Makefile found. Make sure you're in the SSCC project directory."
    fi
  '';
  
  # Meta information
  meta = {
    description = "Development environment for SSCC - Self Sufficient C Compiler";
    longDescription = ''
      This Nix shell provides all the necessary tools to build SSCC,
      a self-contained C compiler based on TCC with integrated musl and GMP libraries.
    '';
  };
}