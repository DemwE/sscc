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

VERSION = 1.1.0

.PHONY: all clean distclean setup deps tcc musl gmp sscc addons test package dist floppy help

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

# Create the modular SSCC binary with addon support
sscc: tcc
	@echo "Creating modular SSCC v$(VERSION) with addon support..."
	mkdir -p $(BUILD_DIR)/sscc
	mkdir -p $(BUILD_DIR)/sscc/temp_lib
	mkdir -p $(BUILD_DIR)/sscc/temp_include
	
	# Copy and optimize TCC binary
	cp $(TCC_DIR)/tcc $(BUILD_DIR)/sscc/sscc.bin
	@echo "Original TCC binary: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"
	
	# Aggressive optimization
	@if command -v strip >/dev/null 2>&1; then \
		strip --strip-all $(BUILD_DIR)/sscc/sscc.bin; \
		echo "Stripped binary: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"; \
	fi
	
	@if command -v upx >/dev/null 2>&1; then \
		upx --ultra-brute $(BUILD_DIR)/sscc/sscc.bin 2>/dev/null || echo "UPX failed, continuing"; \
		echo "Ultra-compressed TCC: $$(du -h $(BUILD_DIR)/sscc/sscc.bin | cut -f1)"; \
	fi
	
	# Prepare minimal core resources (absolute essentials only!)
	@echo "Preparing minimal core resources..."
	# Essential TCC runtime only
	cp $(TCC_DIR)/libtcc1.a $(BUILD_DIR)/sscc/temp_lib/
	# Minimal musl headers - only what's needed for basic compilation
	mkdir -p $(BUILD_DIR)/sscc/temp_include/bits
	cp $(BUILD_DIR)/musl/include/stdio.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/stdlib.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/string.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/stddef.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/stdint.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/stdarg.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/stdbool.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/math.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/errno.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/assert.h $(BUILD_DIR)/sscc/temp_include/
	cp $(BUILD_DIR)/musl/include/features.h $(BUILD_DIR)/sscc/temp_include/
	cp $(MUSL_DIR)/obj/include/bits/alltypes.h $(BUILD_DIR)/sscc/temp_include/bits/
	cp $(MUSL_DIR)/obj/include/bits/syscall.h $(BUILD_DIR)/sscc/temp_include/bits/
	-cp $(MUSL_DIR)/obj/include/bits/stdint.h $(BUILD_DIR)/sscc/temp_include/bits/ 2>/dev/null || true
	# Core libraries only
	cp $(BUILD_DIR)/musl/lib/libc.a $(BUILD_DIR)/sscc/temp_lib/
	cp $(BUILD_DIR)/musl/lib/libm.a $(BUILD_DIR)/sscc/temp_lib/
	
	# Build minimal core embedder with LZMA
	@echo "Building resource embedder..."
	gcc -O2 -o $(BUILD_DIR)/sscc/embed_resources src/embed_resources.c -llzma
	
	# Build binary to C converter
	gcc -O2 -o $(BUILD_DIR)/sscc/bin2c src/bin2c.c
	
	# Create minimal core archive
	@echo "Creating ultra-compressed core archive..."
	$(BUILD_DIR)/sscc/embed_resources $(BUILD_DIR)/sscc/temp_include $(BUILD_DIR)/sscc/temp_lib $(BUILD_DIR)/sscc/core.bin
	
	# Convert to C source
	$(BUILD_DIR)/sscc/bin2c $(BUILD_DIR)/sscc/core.bin $(BUILD_DIR)/sscc/core.c sscc_archive
	
	# Convert TCC binary to C source
	$(BUILD_DIR)/sscc/bin2c $(BUILD_DIR)/sscc/sscc.bin $(BUILD_DIR)/sscc/tcc_binary.c tcc_binary
	
	# Build modular SSCC wrapper with embedded TCC binary
	@echo "Building self-contained SSCC wrapper..."
	gcc -O2 -o build/sscc/sscc src/sscc.c build/sscc/core.c build/sscc/tcc_binary.c -llzma
	
	# Ultra-aggressive compression on final binary
	@if command -v upx >/dev/null 2>&1; then \
		upx --ultra-brute $(BUILD_DIR)/sscc/sscc 2>/dev/null || echo "UPX failed on wrapper"; \
	fi
	
	# Clean up temporary files
	rm -rf $(BUILD_DIR)/sscc/temp_include $(BUILD_DIR)/sscc/temp_lib
	rm -f $(BUILD_DIR)/sscc/embed_resources $(BUILD_DIR)/sscc/bin2c $(BUILD_DIR)/sscc/core.bin $(BUILD_DIR)/sscc/core.c $(BUILD_DIR)/sscc/tcc_binary.c
	# Remove sscc.bin since TCC binary is now embedded in sscc
	rm -f $(BUILD_DIR)/sscc/sscc.bin
	
	@echo "✅ SSCC built successfully!"
	@echo "Self-contained binary: $(BUILD_DIR)/sscc/sscc ($$(du -h $(BUILD_DIR)/sscc/sscc | cut -f1))"
	@echo ""
	@echo "✅ Ready for deployment! Single self-contained executable."

# Create addon files for modular deployment
addons: sscc
	@echo "Creating addon files..."
	gcc -O2 -o $(BUILD_DIR)/sscc/create_addon src/create_addon.c -llzma
	@echo "✅ Addon creator built"
	@echo ""
	@echo "Creating libextra addon with all additional musl libraries..."
	cd $(BUILD_DIR)/sscc && ./create_addon libextra \
		"Extended musl libraries - full POSIX functionality" \
		../../build/musl/include \
		../../build/musl/lib \
		sscc-libextra.addon
	@echo ""
	@echo "Creating GMP addon..."
	cd $(BUILD_DIR)/sscc && ./create_addon gmp \
		"GNU Multiple Precision Arithmetic Library" \
		../../build/gmp/include \
		../../build/gmp/lib \
		sscc-gmp.addon
	@echo ""
	# Clean up the create_addon utility for release
	rm -f $(BUILD_DIR)/sscc/create_addon
	@echo "✅ Addon files created successfully!"
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
	@echo "  sscc      - Create SSCC binary with minimal core"
	@echo "  addons    - Create addon files for modular deployment"
	@echo "  test      - Test the built compiler"
	@echo ""
	@echo "Package Targets:"
	@echo "  floppy    - Create complete floppy package"
	@echo "  package   - Create portable package (alias for floppy)"
	@echo "  dist      - Create distribution archives"
	@echo "  diskette  - Create 1.44MB floppy disk image"
	@echo ""
	@echo "Maintenance:"
	@echo "  install   - Install SSCC to system"
	@echo "  clean     - Clean build artifacts"
	@echo "  distclean - Clean everything including downloads"
	@echo "  help      - Show this help"
	@echo ""
	@echo "Usage Examples:"
	@echo "  make && make test                    # Build and test"
	@echo "  make floppy                         # Create portable package"
	@echo "  ./build/sscc/sscc -o hello hello.c  # Use compiler"


package: floppy
	@echo "✅ Package target complete (alias for floppy)"

# Create distribution tarballs
dist: floppy
	@echo "Creating distribution archives..."
	@cd dist && tar -czf sscc-$(VERSION)-floppy-linux-x86_64.tar.gz sscc-$(VERSION)/
	@cd dist && tar -cJf sscc-$(VERSION)-floppy-linux-x86_64.tar.xz sscc-$(VERSION)/
	@echo "Distribution files:"
	@ls -lh dist/sscc-$(VERSION)-floppy-linux-x86_64.*
	@echo "✅ Distribution archives created in dist/"

# Create a 1.44MB diskette image (requires mtools)
diskette: package
	@echo "Creating 1.44MB diskette image..."
	@if ! command -v mcopy >/dev/null 2>&1; then \
		echo "Error: mtools not found. Install with: sudo apt-get install mtools"; \
		exit 1; \
	fi
	@# Check if package fits on diskette
	@PACKAGE_SIZE=$$(du -s dist/sscc-$(VERSION) | cut -f1); \
	if [ $$PACKAGE_SIZE -gt 1440 ]; then \
		echo "Warning: Package size ($$PACKAGE_SIZE KB) might not fit on 1.44MB diskette (1440 KB)"; \
	else \
		echo "Package size: $$PACKAGE_SIZE KB - fits on diskette!"; \
	fi
	@# Create diskette image
	@dd if=/dev/zero of=dist/sscc-$(VERSION)-diskette.img bs=1024 count=1440 2>/dev/null
	@mformat -i dist/sscc-$(VERSION)-diskette.img -f 1440 ::
	@mmd -i dist/sscc-$(VERSION)-diskette.img ::sscc
	@mcopy -i dist/sscc-$(VERSION)-diskette.img dist/sscc-$(VERSION)/* ::sscc/
	@# Create autoexec.bat for DOS compatibility
	@echo "@echo off" > /tmp/autoexec.bat
	@echo "echo SSCC v$(VERSION) - Self Sufficient C Compiler" >> /tmp/autoexec.bat
	@echo "echo Diskette Edition" >> /tmp/autoexec.bat
	@echo "echo." >> /tmp/autoexec.bat
	@echo "echo To use: cd sscc && ./sscc -o hello hello.c" >> /tmp/autoexec.bat
	@mcopy -i dist/sscc-$(VERSION)-diskette.img /tmp/autoexec.bat ::
	@rm /tmp/autoexec.bat
	@echo "✅ Diskette image created: dist/sscc-$(VERSION)-diskette.img"
	@echo "💾 Ready to write to physical diskette!"
	@echo ""
	@echo "To write to diskette (Linux): dd if=dist/sscc-$(VERSION)-diskette.img of=/dev/fd0"
	@echo "To mount as loop device: sudo mount -o loop dist/sscc-$(VERSION)-diskette.img /mnt"

# Test the packaged version
test-package: package
	@echo "Testing portable package..."
	@cd dist/sscc-$(VERSION) && ./test.sh
	@echo "✅ Package test completed successfully!"

floppy: sscc addons
	@echo "Creating complete floppy package..."
	@mkdir -p dist/sscc-$(VERSION)
	@cp -r $(BUILD_DIR)/sscc/* dist/sscc-$(VERSION)/
	# Remove sscc.bin since it's now embedded in sscc
	rm -f dist/sscc-$(VERSION)/sscc.bin
	@echo "✅ Floppy package created in dist/sscc-$(VERSION)/"
	@echo "Package size: $$(du -sh dist/sscc-$(VERSION) | cut -f1)"
