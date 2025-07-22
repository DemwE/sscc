set -euo pipefail

echo "Cleaning previous builds..."
make clean

echo "Building project with embedded resources..."
make -j"$(nproc)"

echo "Creating portable package..."
make package

echo "Creating distribution archives..."
make dist

echo "Creating diskette image..."
make diskette || echo "Note: Diskette creation requires mtools (optional)"