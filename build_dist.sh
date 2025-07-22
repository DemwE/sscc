# SSCC Distribution Builder
# Builds the complete SSCC self-contained C compiler with addons

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Check dependencies
check_deps() {
    log "Checking build dependencies..."
    
    local deps=("gcc" "make" "wget" "tar" "autoconf" "automake" "libtool" "m4")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}"
    fi
    
    # Check optional dependencies
    if ! command -v upx >/dev/null 2>&1; then
        warning "UPX not found - binary compression will be skipped"
    fi
    
    if ! command -v lzma >/dev/null 2>&1; then
        error "LZMA library not found - required for compression"
    fi
    
    success "All required dependencies found"
}

# Clean previous builds
clean_build() {
    log "Cleaning previous builds..."
    make clean 2>/dev/null || true
    rm -rf dist/ 2>/dev/null || true
    success "Build cleaned"
}

# Build the project
build_project() {
    log "Building SSCC with self-contained TCC binary..."
    
    # Use all available CPU cores for parallel build
    local cores=$(nproc 2>/dev/null || echo "4")
    
    log "Using $cores parallel jobs for build"
    
    # Build with error handling
    if ! make -j"$cores"; then
        error "Build failed"
    fi
    
    success "SSCC core built successfully"
}

# Create addons
build_addons() {
    log "Creating addon packages..."
    
    if ! make addons; then
        error "Addon creation failed"
    fi
    
    success "Addons created successfully"
}

# Create distribution package
create_package() {
    log "Creating portable distribution package..."
    
    if ! make floppy; then
        error "Package creation failed"
    fi
    
    success "Portable package created"
}

# Create compressed archives
create_archives() {
    log "Creating distribution archives..."
    
    if ! make dist; then
        error "Archive creation failed"
    fi
    
    success "Distribution archives created"
}

# Create diskette image (optional)
create_diskette() {
    log "Creating diskette image..."
    
    if command -v mtools >/dev/null 2>&1; then
        if make diskette; then
            success "Diskette image created"
        else
            warning "Diskette creation failed"
        fi
    else
        warning "mtools not available - skipping diskette creation"
    fi
}

# Test the build
test_build() {
    log "Testing the built compiler..."
    
    if ! make test; then
        error "Build test failed"
    fi
    
    success "Build test passed"
}

# Show build results
show_results() {
    log "Build Summary:"
    echo
    
    if [ -d "build/sscc" ]; then
        echo "📁 Core Files:"
        ls -lh build/sscc/sscc build/sscc/sscc.bin 2>/dev/null || true
        echo
        
        echo "📦 Addon Files:"
        ls -lh build/sscc/*.addon 2>/dev/null || echo "  No addon files found"
        echo
    fi
    
    if [ -d "dist" ]; then
        echo "📊 Distribution Files:"
        du -sh dist/* 2>/dev/null || echo "  No distribution files found"
        echo
        
        if [ -f "dist/sscc-"*"-diskette.img" ]; then
            echo "💾 Diskette Image:"
            ls -lh dist/*-diskette.img
            echo
        fi
    fi
    
    success "SSCC build completed successfully!"
    echo
    echo "Usage:"
    echo "  ./build/sscc/sscc -o hello hello.c    # Compile with core"
    echo "  ./build/sscc/sscc --list-addons       # List available addons"
    echo "  ./build/sscc/sscc --help              # Show help"
    echo
    echo "Distribution packages available in dist/ directory"
}

# Main build process
main() {
    echo "🚀 SSCC Distribution Builder"
    echo "============================="
    echo
    
    check_deps
    clean_build
    build_project
    build_addons
    test_build
    create_package
    create_archives
    create_diskette
    show_results
}

# Handle script interruption
trap 'error "Build interrupted"' INT TERM

# Run main function
main "$@"