{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  name = "sscc-build-env";
  
  buildInputs = with pkgs; [
    # Core build tools
    gcc
    gnumake
    binutils
    
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
    
    # Build dependencies for musl and GMP
    flex
    bison
    
    # Additional utilities
    file
    which
    coreutils
    findutils
    diffutils
    patch
    upx
    
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
    echo ""
    echo "🚀 To build SSCC:"
    echo "   make           # Build everything"
    echo "   make package   # Create portable package"
    echo "   make dist      # Create distribution archives"
    echo "   make test      # Test the built compiler"
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