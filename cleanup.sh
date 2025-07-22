#!/bin/bash
# SSCC Project Cleanup Script
# Removes unnecessary test files and organizes the project

set -euo pipefail

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "🧹 SSCC Project Cleanup"
echo "======================="

# Remove test binaries and temporary files
log "Removing test binaries and temporary files..."
rm -f test_core simple test_addon comprehensive_test
rm -f hello musl_test gmp_test simple_test
rm -f *.o *.a *.so *.exe *.tmp *.log
rm -f *~ .#*

# Remove test source files (keeping them would be redundant)
log "Removing redundant test source files..."
rm -f test_core.c simple.c test_addon.c comprehensive_test.c

# Remove any leftover addon files in root (they should be in build/)
log "Removing stray addon files..."
rm -f *.addon

# Remove editor temporary files
log "Removing editor temporary files..."
rm -f *.swp *.swo *~
rm -rf .vscode/ .idea/

# Remove OS generated files  
log "Removing OS generated files..."
rm -f .DS_Store .DS_Store? ._* .Spotlight-V100 .Trashes
rm -f ehthumbs.db Thumbs.db

# Clean up any test results directories
log "Removing test directories..."
rm -rf test_results/

# Remove Nix result links
log "Removing Nix result links..."
rm -f result result-*

# Remove direnv cache
log "Removing direnv cache..."
rm -rf .direnv/

echo
echo "🎉 Project cleanup completed!"
echo
echo "Remaining structure:"
echo "├── src/               # Source code"
echo "├── build_dist.sh      # Distribution builder"
echo "├── Makefile          # Build system"
echo "├── README.md         # Documentation"
echo "├── shell.nix         # Nix development environment"
echo "├── .envrc            # direnv configuration"
echo "└── .gitignore        # Git ignore rules"
echo
echo "To build: ./build_dist.sh"
