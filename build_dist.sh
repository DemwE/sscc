set -euo pipefail

echo "Cleaning previous builds..."
make clean

echo "Building project..."
make -j"$(nproc)"

echo "Packaging project..."
make package

echo "Creating distribution..."
make dist

echo "Build and packaging complete."
