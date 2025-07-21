# SSCC - Self Sufficient C Compiler Makefile

# Directories
TCC_DIR = tcc
MUSL_DIR = musl
GMP_DIR = gmp
BUILD_DIR = build
PREFIX = /usr/local

# TCC repository
TCC_REPO = https://repo.or.cz/tinycc.git
MUSL_REPO = https://git.musl-libc.org/cgit/musl
GMP_REPO = https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz

# Build flags
CFLAGS = -O2 -Wall
LDFLAGS = -static

VERSION = 1.0.0

.PHONY: all clean distclean setup deps tcc musl gmp sscc package dist test-package

all: sscc

# Setup directories and download dependencies
setup:
	mkdir -p $(BUILD_DIR)
	mkdir -p deps

deps: setup
	@echo "Downloading TCC..."
	if [ ! -d $(TCC_DIR) ]; then \
		git clone $(TCC_REPO) $(TCC_DIR); \
	fi
	@echo "Downloading musl..."
	if [ ! -d $(MUSL_DIR) ]; then \
		wget -O musl.tar.gz https://musl.libc.org/releases/musl-1.2.4.tar.gz; \
		tar -xzf musl.tar.gz; \
		mv musl-1.2.4 $(MUSL_DIR); \
		rm musl.tar.gz; \
	fi
	@echo "Downloading GMP..."
	if [ ! -d $(GMP_DIR) ]; then \
		wget -O gmp.tar.xz https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz; \
		tar -xf gmp.tar.xz; \
		mv gmp-6.3.0 $(GMP_DIR); \
		rm gmp.tar.xz; \
	fi

# Build musl
musl: deps
	@echo "Building musl..."
	cd $(MUSL_DIR) && \
	./configure --prefix=$(PWD)/$(BUILD_DIR)/musl --disable-shared --enable-static && \
	$(MAKE) && $(MAKE) install

# Build GMP
gmp: deps
	@echo "Building GMP..."
	cd $(GMP_DIR) && \
	./configure --prefix=$(PWD)/$(BUILD_DIR)/gmp --disable-shared --enable-static && \
	$(MAKE) && $(MAKE) install

# Build TCC with integrated libraries
tcc: musl gmp
	@echo "Building TCC..."
	cd $(TCC_DIR) && \
	./configure --prefix=$(PWD)/$(BUILD_DIR)/tcc \
		--crtprefix=$(PWD)/$(BUILD_DIR)/musl/lib \
		--libpaths=$(PWD)/$(BUILD_DIR)/musl/lib:$(PWD)/$(BUILD_DIR)/gmp/lib \
		--config-musl && \
	$(MAKE) CPPFLAGS="-I$(PWD)/$(BUILD_DIR)/musl/include -I$(PWD)/$(BUILD_DIR)/gmp/include" \
		CFLAGS="-I$(PWD)/$(BUILD_DIR)/musl/include -I$(PWD)/$(BUILD_DIR)/gmp/include" \
		LDFLAGS="-L$(PWD)/$(BUILD_DIR)/musl/lib -L$(PWD)/$(BUILD_DIR)/gmp/lib" \
		CC=gcc tcc
	@echo "Building TCC runtime library with proper headers..."
	cd $(TCC_DIR)/lib && \
	CPPFLAGS="-I$(PWD)/$(BUILD_DIR)/musl/include" \
	C_INCLUDE_PATH="$(PWD)/$(BUILD_DIR)/musl/include" \
	$(MAKE) TCC="../tcc -I$(PWD)/$(BUILD_DIR)/musl/include -I$(PWD)/$(BUILD_DIR)/gmp/include -B.."

# Create the self-sufficient SSCC binary
sscc: tcc
	@echo "Creating SSCC binary..."
	mkdir -p $(BUILD_DIR)/sscc
	mkdir -p $(BUILD_DIR)/sscc/lib/tcc
	mkdir -p $(BUILD_DIR)/sscc/include
	# Copy TCC binary
	cp $(TCC_DIR)/tcc $(BUILD_DIR)/sscc/sscc.bin
	@echo "Original binary size: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"
	# Strip debug symbols
	@echo "Stripping debug symbols..."
	@if command -v strip >/dev/null 2>&1; then \
		strip $(BUILD_DIR)/sscc/sscc.bin; \
		echo "Stripped binary size: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"; \
	else \
		echo "Warning: strip command not available"; \
	fi
	# Compress with UPX if available
	@if command -v upx >/dev/null 2>&1; then \
		echo "Compressing binary with UPX..."; \
		upx --best --lzma $(BUILD_DIR)/sscc/sscc.bin 2>/dev/null || echo "UPX compression failed, continuing"; \
		echo "Final compressed size: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"; \
	else \
		echo "Warning: UPX not available for compression"; \
	fi
	# Create wrapper script
	echo '#!/run/current-system/sw/bin/bash' > $(BUILD_DIR)/sscc/sscc
	echo 'SCRIPT_DIR="$$( cd "$$( dirname "$${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"' >> $(BUILD_DIR)/sscc/sscc
	echo 'SSCC_INCLUDE="$$SCRIPT_DIR/include"' >> $(BUILD_DIR)/sscc/sscc
	echo 'SSCC_LIB="$$SCRIPT_DIR/lib/tcc"' >> $(BUILD_DIR)/sscc/sscc
	echo 'exec "$$SCRIPT_DIR/sscc.bin" -I"$$SSCC_INCLUDE" -L"$$SSCC_LIB" -B"$$SSCC_LIB" "$$@"' >> $(BUILD_DIR)/sscc/sscc
	chmod +x $(BUILD_DIR)/sscc/sscc
	# Copy TCC runtime libraries
	cp $(TCC_DIR)/libtcc1.a $(BUILD_DIR)/sscc/lib/tcc/
	cp $(TCC_DIR)/*.o $(BUILD_DIR)/sscc/lib/tcc/ 2>/dev/null || true
	# Copy musl headers and libraries
	cp -r $(BUILD_DIR)/musl/include/* $(BUILD_DIR)/sscc/include/
	cp $(BUILD_DIR)/musl/lib/*.a $(BUILD_DIR)/sscc/lib/tcc/
	# Copy GMP headers and libraries
	cp -r $(BUILD_DIR)/gmp/include/* $(BUILD_DIR)/sscc/include/
	cp $(BUILD_DIR)/gmp/lib/*.a $(BUILD_DIR)/sscc/lib/tcc/
	@echo "SSCC built successfully at $(BUILD_DIR)/sscc/sscc"
	@echo "Complete package size: $$(du -sh $(BUILD_DIR)/sscc | cut -f1)"

# Install SSCC
install: sscc
	install -m 755 $(BUILD_DIR)/sscc/sscc $(PREFIX)/bin/
	@echo "SSCC installed to $(PREFIX)/bin/sscc"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	if [ -d $(TCC_DIR) ]; then cd $(TCC_DIR) && $(MAKE) clean; fi
	if [ -d $(MUSL_DIR) ]; then cd $(MUSL_DIR) && $(MAKE) clean; fi
	if [ -d $(GMP_DIR) ]; then cd $(GMP_DIR) && $(MAKE) clean; fi

# Clean everything including dependencies
distclean: clean
	rm -rf $(TCC_DIR) $(MUSL_DIR) $(GMP_DIR)

help:
	@echo "SSCC Build System"
	@echo "=================="
	@echo "Targets:"
	@echo "  all      - Build SSCC (default)"
	@echo "  deps     - Download dependencies"
	@echo "  musl     - Build musl library"
	@echo "  gmp      - Build GMP library"
	@echo "  tcc      - Build TCC compiler"
	@echo "  sscc     - Create final SSCC binary"
	@echo "  install  - Install SSCC to system"
	@echo "  clean    - Clean build artifacts"
	@echo "  distclean- Clean everything"
	@echo "  help     - Show this help"

# Create a portable distribution package
package: sscc
	@echo "Creating portable SSCC package..."
	@mkdir -p dist
	@rm -rf dist/sscc-$(VERSION)
	@cp -r build/sscc dist/sscc-$(VERSION)
	@# Fix shebang for portability
	@sed -i '1s|.*|#!/usr/bin/env bash|' dist/sscc-$(VERSION)/sscc
	@# Create package test script
	@echo '#!/usr/bin/env bash' > dist/sscc-$(VERSION)/test.sh
	@echo 'set -e' >> dist/sscc-$(VERSION)/test.sh
	@echo 'echo "Testing SSCC package..."' >> dist/sscc-$(VERSION)/test.sh
	@echo 'cd "$$(dirname "$$0")"' >> dist/sscc-$(VERSION)/test.sh
	@echo 'echo "int main(){printf(\"Hello from SSCC!\\\\n\");return 0;}" > test.c' >> dist/sscc-$(VERSION)/test.sh
	@echo './sscc -static -o test test.c' >> dist/sscc-$(VERSION)/test.sh
	@echo './test' >> dist/sscc-$(VERSION)/test.sh
	@echo 'rm -f test test.c' >> dist/sscc-$(VERSION)/test.sh
	@echo 'echo "✅ SSCC package test passed!"' >> dist/sscc-$(VERSION)/test.sh
	@chmod +x dist/sscc-$(VERSION)/test.sh
	@# Create README for the package
	@echo "# SSCC - Self Sufficient C Compiler v$(VERSION)" > dist/sscc-$(VERSION)/README.txt
	@echo "" >> dist/sscc-$(VERSION)/README.txt
	@echo "This is a portable, self-contained C compiler package." >> dist/sscc-$(VERSION)/README.txt
	@echo "" >> dist/sscc-$(VERSION)/README.txt
	@echo "Usage:" >> dist/sscc-$(VERSION)/README.txt
	@echo "  ./sscc -o program program.c" >> dist/sscc-$(VERSION)/README.txt
	@echo "  ./sscc -static -o program program.c  # Recommended" >> dist/sscc-$(VERSION)/README.txt
	@echo "" >> dist/sscc-$(VERSION)/README.txt
	@echo "Test the package:" >> dist/sscc-$(VERSION)/README.txt
	@echo "  ./test.sh" >> dist/sscc-$(VERSION)/README.txt
	@echo "" >> dist/sscc-$(VERSION)/README.txt
	@echo "Package contents:" >> dist/sscc-$(VERSION)/README.txt
	@echo "  sscc      - Compiler wrapper script" >> dist/sscc-$(VERSION)/README.txt
	@echo "  sscc.bin  - TCC compiler binary ($(shell du -h build/sscc/sscc.bin | cut -f1))" >> dist/sscc-$(VERSION)/README.txt
	@echo "  include/  - C standard library headers" >> dist/sscc-$(VERSION)/README.txt
	@echo "  lib/      - Static libraries (musl, GMP, TCC runtime)" >> dist/sscc-$(VERSION)/README.txt
	@echo "" >> dist/sscc-$(VERSION)/README.txt
	@echo "No system dependencies required - completely self-contained!" >> dist/sscc-$(VERSION)/README.txt
	@du -sh dist/sscc-$(VERSION)
	@echo "✅ Portable package created at dist/sscc-$(VERSION)/"

# Create distribution tarballs
dist: package
	@echo "Creating distribution archives..."
	@cd dist && tar -czf sscc-$(VERSION)-linux-x86_64.tar.gz sscc-$(VERSION)/
	@cd dist && tar -cJf sscc-$(VERSION)-linux-x86_64.tar.xz sscc-$(VERSION)/
	@echo "Distribution files:"
	@ls -lh dist/sscc-$(VERSION)-linux-x86_64.*
	@echo "✅ Distribution archives created in dist/"

# Test the packaged version
test-package: package
	@echo "Testing portable package..."
	@cd dist/sscc-$(VERSION) && ./test.sh
	@echo "✅ Package test completed successfully!"
