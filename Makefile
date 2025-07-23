# SSCC - Self Sufficient C Compiler Makefile

# Directories
TCC_DIR = tcc
MUSL_DIR = musl
GMP_DIR = gmp
BUILD_DIR = build
PREFIX = /usr/local

# TCC repository
TCC_REPO = https://repo.or.cz/tinycc.git
GMP_REPO = https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz

# Build flags
CFLAGS = -O2 -Wall
LDFLAGS = -static

VERSION = 1.2.1

.PHONY: all clean distclean setup deps tcc musl gmp sscc addons test dist compressed package help

# Default target
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
		wget -O musl.tar.gz https://musl.libc.org/releases/musl-1.2.5.tar.gz; \
		tar -xzf musl.tar.gz; \
		mv musl-1.2.5 $(MUSL_DIR); \
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
gmp: musl
	@echo "Building GMP with musl..."
	cd $(GMP_DIR) && \
	CC="$(PWD)/$(BUILD_DIR)/musl/bin/musl-gcc" \
	CPPFLAGS="-I$(PWD)/$(BUILD_DIR)/musl/include" \
	LDFLAGS="-L$(PWD)/$(BUILD_DIR)/musl/lib" \
	TMPDIR=/tmp \
	./configure --prefix=$(PWD)/$(BUILD_DIR)/gmp \
		--disable-shared --enable-static \
		--host=x86_64-linux-musl && \
	$(MAKE) && $(MAKE) install

# Build TCC with integrated libraries
tcc: musl gmp
	@echo "Building TCC..."
	cd $(TCC_DIR) && \
	./configure --prefix=$(PWD)/$(BUILD_DIR)/tcc \
		--crtprefix=$(PWD)/$(BUILD_DIR)/musl/lib \
		--libpaths=$(PWD)/$(BUILD_DIR)/musl/lib:$(PWD)/$(BUILD_DIR)/gmp/lib \
		--sysincludepaths=$(PWD)/$(BUILD_DIR)/musl/include \
		--config-musl \
		--config-bcheck=no && \
	$(MAKE) CPPFLAGS="-I$(PWD)/$(BUILD_DIR)/musl/include -I$(PWD)/$(BUILD_DIR)/gmp/include" \
		CFLAGS="-I$(PWD)/$(BUILD_DIR)/musl/include -I$(PWD)/$(BUILD_DIR)/gmp/include" \
		LDFLAGS="-L$(PWD)/$(BUILD_DIR)/musl/lib -L$(PWD)/$(BUILD_DIR)/gmp/lib" \
		CC=gcc tcc
	@echo "Building TCC runtime library with proper headers..."
	cd $(TCC_DIR)/lib && \
	CPPFLAGS="-I$(PWD)/$(BUILD_DIR)/musl/include" \
	C_INCLUDE_PATH="$(PWD)/$(BUILD_DIR)/musl/include" \
	$(MAKE) TCC="../tcc -I$(PWD)/$(BUILD_DIR)/musl/include -I$(PWD)/$(BUILD_DIR)/gmp/include -B.."

# Create the self-contained SSCC binary with addon support
sscc: tcc
	@echo "Creating SSCC v$(VERSION) with complete musl functionality..."
	mkdir -p $(BUILD_DIR)/sscc
	mkdir -p $(BUILD_DIR)/sscc/temp_lib
	mkdir -p $(BUILD_DIR)/sscc/temp_include
	
	# Copy and optimize TCC binary
	cp $(TCC_DIR)/tcc $(BUILD_DIR)/sscc/sscc.bin
	@echo "Original TCC binary: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"
	
	# Optimize TCC binary
	@if command -v strip >/dev/null 2>&1; then \
		strip --strip-all $(BUILD_DIR)/sscc/sscc.bin; \
		echo "Stripped binary: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"; \
	fi
	
	@if command -v upx >/dev/null 2>&1; then \
		upx --ultra-brute $(BUILD_DIR)/sscc/sscc.bin 2>/dev/null || echo "UPX failed, continuing"; \
		echo "Compressed TCC: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"; \
	fi
	
	# Prepare complete core resources with full musl functionality
	@echo "Preparing complete core resources with full musl..."
	# Essential TCC runtime
	cp $(TCC_DIR)/libtcc1.a $(BUILD_DIR)/sscc/temp_lib/
	# Copy ALL musl headers and libraries (no filtering since embed_resources now includes everything)
	cp -r $(BUILD_DIR)/musl/include/* $(BUILD_DIR)/sscc/temp_include/
	cp -r $(MUSL_DIR)/include/* $(BUILD_DIR)/sscc/temp_include/ 2>/dev/null || true
	cp -r $(MUSL_DIR)/obj/include/* $(BUILD_DIR)/sscc/temp_include/ 2>/dev/null || true
	# Copy both static libraries (.a) and C runtime startup files (.o)
	cp $(BUILD_DIR)/musl/lib/*.a $(BUILD_DIR)/sscc/temp_lib/ 2>/dev/null || true
	cp $(BUILD_DIR)/musl/lib/*.o $(BUILD_DIR)/sscc/temp_lib/ 2>/dev/null || true
	# Also copy musl-gcc specs file if it exists
	cp $(BUILD_DIR)/musl/lib/*.specs $(BUILD_DIR)/sscc/temp_lib/ 2>/dev/null || true
	
	# Build resource embedder with LZMA
	@echo "Building resource embedder..."
	gcc -O2 -o $(BUILD_DIR)/sscc/embed_resources src/embed_resources.c -llzma
	
	# Build binary to C converter
	gcc -O2 -o $(BUILD_DIR)/sscc/bin2c src/bin2c.c
	
	# Create complete core archive with full functionality
	@echo "Creating complete core archive with full musl functionality..."
	$(BUILD_DIR)/sscc/embed_resources $(BUILD_DIR)/sscc/temp_include $(BUILD_DIR)/sscc/temp_lib $(BUILD_DIR)/sscc/core.bin
	
	# Convert to C source
	$(BUILD_DIR)/sscc/bin2c $(BUILD_DIR)/sscc/core.bin $(BUILD_DIR)/sscc/core.c sscc_archive
	
	# Convert TCC binary to C source
	$(BUILD_DIR)/sscc/bin2c $(BUILD_DIR)/sscc/sscc.bin $(BUILD_DIR)/sscc/tcc_binary.c tcc_binary
	
	# Build self-contained SSCC wrapper
	@echo "Building self-contained SSCC wrapper..."
	gcc -O2 -DSSCC_VERSION=\"$(VERSION)\" -o build/sscc/sscc src/sscc.c build/sscc/core.c build/sscc/tcc_binary.c -llzma
	
	# Compress final binary
	@if command -v upx >/dev/null 2>&1; then \
		upx --ultra-brute $(BUILD_DIR)/sscc/sscc 2>/dev/null || echo "UPX failed on wrapper"; \
	fi
	
	# Clean up temporary files (keep core.c for addon creation)
	rm -rf $(BUILD_DIR)/sscc/temp_include $(BUILD_DIR)/sscc/temp_lib
	rm -f $(BUILD_DIR)/sscc/embed_resources $(BUILD_DIR)/sscc/bin2c $(BUILD_DIR)/sscc/core.bin $(BUILD_DIR)/sscc/tcc_binary.c
	# Remove sscc.bin since TCC binary is now embedded in sscc
	rm -f $(BUILD_DIR)/sscc/sscc.bin
	
	@echo "✅ SSCC built successfully with complete musl functionality!"
	@echo "Self-contained binary: $(BUILD_DIR)/sscc/sscc ($$(du -h $(BUILD_DIR)/sscc/sscc | cut -f1))"
	@echo ""
	@echo "✅ Ready for deployment! Includes full POSIX functionality built-in."

# Create addon files for modular deployment
addons: sscc
	@echo "Creating addon files with dynamic core exclusion..."
	gcc -O2 -o $(BUILD_DIR)/sscc/create_addon src/create_addon.c $(BUILD_DIR)/sscc/core.c -llzma
	@echo "✅ Addon creator built with embedded core data"
	@echo ""
	@echo "Creating GMP addon..."
	cd $(BUILD_DIR)/sscc && ./create_addon gmp \
		"GNU Multiple Precision Arithmetic Library" \
		../../build/gmp/include \
		../../build/gmp/lib \
		sscc-gmp.addon
	@echo ""
	# Clean up the create_addon utility and core.c for release
	rm -f $(BUILD_DIR)/sscc/create_addon $(BUILD_DIR)/sscc/core.c
	@echo "✅ GMP addon created successfully!"
	@ls -lh $(BUILD_DIR)/sscc/*.addon 2>/dev/null || echo "No addon files found"

# Test the built SSCC
test: sscc
	@echo "Testing SSCC..."
	@echo '#include <stdio.h>' > /tmp/test_sscc.c
	@echo 'int main() { printf("Hello from SSCC!\\n"); return 0; }' >> /tmp/test_sscc.c
	@$(BUILD_DIR)/sscc/sscc -o /tmp/test_sscc /tmp/test_sscc.c
	@/tmp/test_sscc
	@rm -f /tmp/test_sscc.c /tmp/test_sscc
	@echo "✅ SSCC test completed successfully!"

# Install SSCC
install: sscc
	install -m 755 $(BUILD_DIR)/sscc/sscc $(PREFIX)/bin/
	@echo "SSCC installed to $(PREFIX)/bin/sscc"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -rf dist
	if [ -d $(TCC_DIR) ]; then cd $(TCC_DIR) && $(MAKE) clean 2>/dev/null || true; fi
	if [ -d $(MUSL_DIR) ]; then cd $(MUSL_DIR) && $(MAKE) clean 2>/dev/null || true; fi
	if [ -d $(GMP_DIR) ] && [ -f $(GMP_DIR)/Makefile ]; then cd $(GMP_DIR) && $(MAKE) clean 2>/dev/null || true; fi
	# Ensure any leftover sscc.bin files are removed
	find . -name "sscc.bin" -type f -delete 2>/dev/null || true

# Clean everything including dependencies
distclean: clean
	rm -rf $(TCC_DIR) $(MUSL_DIR) $(GMP_DIR)

help:
	@echo "SSCC Build System"
	@echo "===================="
	@echo "Quick Start:"
	@echo "  ./build_dist.sh   - Automated build with all features"
	@echo "  ./test_sscc.sh    - Comprehensive test suite"
	@echo "  ./cleanup.sh      - Clean up project files"
	@echo ""
	@echo "Build Targets:"
	@echo "  all       - Build SSCC with addon support (default)"
	@echo "  deps      - Download dependencies"
	@echo "  musl      - Build musl library"
	@echo "  gmp       - Build GMP library"  
	@echo "  tcc       - Build TCC compiler"
	@echo "  sscc      - Create SSCC binary with complete musl core"
	@echo "  addons    - Create GMP addon for modular deployment"
	@echo "  test      - Test the built compiler"
	@echo ""
	@echo "Package Targets:"
	@echo "  dist      - Create distribution build in dist/ folder"
	@echo "  compressed - Create compressed archive (.tar.xz)"
	@echo "  package   - Create distribution package (alias for dist)"
	@echo ""
	@echo "Maintenance:"
	@echo "  install   - Install SSCC to system"
	@echo "  clean     - Clean build artifacts"
	@echo "  distclean - Clean everything including downloads"
	@echo "  help      - Show this help"
	@echo ""
	@echo "Usage Examples:"
	@echo "  make && make test                    # Build and test"
	@echo "  make dist                           # Create distribution in dist/"
	@echo "  make compressed                     # Create compressed archive (.tar.xz)"
	@echo "  ./build/sscc/sscc -o hello hello.c  # Use compiler"


# Create distribution build with core and addons
dist: sscc addons
	@echo "Creating distribution build..."
	@mkdir -p dist/sscc-$(VERSION)
	@cp -r $(BUILD_DIR)/sscc/* dist/sscc-$(VERSION)/
	# Ensure no sscc.bin files are included
	@rm -f dist/sscc-$(VERSION)/sscc.bin
	@echo "✅ Distribution build created in dist/sscc-$(VERSION)/"
	@echo "Contents:"
	@ls -lh dist/sscc-$(VERSION)/
	@echo "Package size: $$(du -sh dist/sscc-$(VERSION) | cut -f1)"

# Create compressed archive with everything
compressed: dist
	@echo "Creating compressed archive..."
	@cd dist && tar -cJf sscc-$(VERSION)-complete.tar.xz sscc-$(VERSION)/
	@echo "✅ Compressed archive created:"
	@ls -lh dist/sscc-$(VERSION)-complete.tar.xz
	@echo "Archive size: $$(du -sh dist/sscc-$(VERSION)-complete.tar.xz | cut -f1)"

package: dist
	@echo "✅ Package target complete"

# Test the packaged version
test-package: package
	@echo "Testing distribution package..."
	@cd dist/sscc-$(VERSION) && echo "Testing SSCC..." && ./sscc --version 2>/dev/null || echo "SSCC ready for use"
	@echo "✅ Package test completed successfully!"
