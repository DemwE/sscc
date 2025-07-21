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
    
    # Development tools
    pkg-config
    autoconf
    automake
    libtool
    
    # Additional utilities
    file
    which
    coreutils
    upx
  ];
  
  shellHook = ''
    echo "🔧 SSCC Build Environment Ready!"
    echo "📦 Available tools:"
    echo "   • gcc $(gcc --version | head -1 | cut -d' ' -f4)"
    echo "   • make $(make --version | head -1 | cut -d' ' -f3)"
    echo "   • git $(git --version | cut -d' ' -f3)"
    echo "   • upx $(upx --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo 'available')"
    echo ""
    echo "🚀 To build SSCC:"
    echo "   make           # Build everything"
    echo "   make help      # Show all available targets"
    echo ""
    echo "📁 Build output will be in: ./build/sscc/sscc"
    
    # Set environment variables for reproducible builds
    export CC=gcc
    export CXX=g++
    export MAKE=make
    
    # Ensure proper paths
    export PATH="$PWD/build/sscc:$PATH"
    
    # Create .envrc for direnv users
    if command -v direnv >/dev/null 2>&1; then
      if [ ! -f .envrc ]; then
        echo "use nix" > .envrc
        echo "💡 Created .envrc for direnv. Run 'direnv allow' to auto-enter this shell."
      fi
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