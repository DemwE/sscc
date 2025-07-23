#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/mman.h>
#include <stdint.h>
#include <errno.h>
#include <libgen.h>
#include <glob.h>
#include <lzma.h>
#include <fcntl.h>

#define MAX_PATH 4096
#define TEMP_DIR_TEMPLATE "/tmp/sscc_XXXXXX"
#define RAM_FS_TEMPLATE "/tmp/sscc_ram_XXXXXX"

// Version will be provided by Makefile as -DSSCC_VERSION
#ifndef SSCC_VERSION
#define SSCC_VERSION "unknown"
#endif

// Global variables for RAM usage tracking
static size_t total_ram_used = 0;
static int use_ram_filesystem = 1;  // Try RAM filesystem first
static int ram_method = 0;  // 0=failed, 1=memfd, 2=shm, 3=disk

// Check if memfd_create is available
static int try_memfd_create() {
#ifdef __linux__
    // Test if memfd_create works
    int fd = memfd_create("sscc_test", MFD_CLOEXEC);
    if (fd >= 0) {
        close(fd);
        return 1;  // Available
    }
#endif
    return 0;  // Not available
}

static char* get_temp_dir_template() {
    const char* tmpdir = getenv("TMPDIR");
    if (tmpdir == NULL) tmpdir = getenv("TEMP");
    if (tmpdir == NULL) tmpdir = "/tmp";
    
    static char template_buf[MAX_PATH];
    if (use_ram_filesystem) {
        snprintf(template_buf, sizeof(template_buf), "%s/sscc_ram_XXXXXX", tmpdir);
    } else {
        snprintf(template_buf, sizeof(template_buf), "%s/sscc_XXXXXX", tmpdir);
    }
    return template_buf;
}

static void format_bytes(size_t bytes, char *buffer, size_t buffer_size) {
    if (bytes >= 1024 * 1024) {
        snprintf(buffer, buffer_size, "%.2f MB", bytes / (1024.0 * 1024.0));
    } else if (bytes >= 1024) {
        snprintf(buffer, buffer_size, "%.2f KB", bytes / 1024.0);
    } else {
        snprintf(buffer, buffer_size, "%zu bytes", bytes);
    }
}

static int create_memfd_directory(char *temp_dir) {
    if (!try_memfd_create()) {
        return -1;  // memfd not available
    }
    
    // Create a regular directory for the symlink structure
    snprintf(temp_dir, MAX_PATH, "/tmp/sscc_memfd_%d", getpid());
    if (mkdir(temp_dir, 0755) != 0) {
        return -1;
    }
    
    printf("Created memory filesystem using memfd_create: %s\n", temp_dir);
    ram_method = 1;
    return 0;
}

static int create_shm_directory(char *temp_dir) {
    // Try /dev/shm first (most systems have this as tmpfs)
    if (access("/dev/shm", W_OK) == 0) {
        snprintf(temp_dir, MAX_PATH, "/dev/shm/sscc_ram_%d", getpid());
        if (mkdir(temp_dir, 0755) == 0) {
            printf("Created RAM directory using /dev/shm: %s\n", temp_dir);
            ram_method = 2;
            return 0;
        }
    }
    return -1;
}

static int create_disk_directory(char *temp_dir) {
    // Final fallback: regular disk-based temp directory
    char temp_template[] = "/tmp/sscc_disk_XXXXXX";
    if (mkdtemp(temp_template) != NULL) {
        strcpy(temp_dir, temp_template);
        printf("Created disk-based temporary directory: %s\n", temp_dir);
        ram_method = 3;
        use_ram_filesystem = 0;  // Disable RAM-specific features
        return 0;
    }
    return -1;
}

static int create_ram_filesystem(char *temp_dir) {
    // Priority order: memfd > /dev/shm > disk
    
    // 1. Try memfd_create() first (pure memory, no sudo needed)
    if (create_memfd_directory(temp_dir) == 0) {
        return 0;
    }
    
    // 2. Try /dev/shm (RAM filesystem, no sudo needed)
    if (create_shm_directory(temp_dir) == 0) {
        return 0;
    }
    
    // 3. Final fallback: disk-based directory
    if (create_disk_directory(temp_dir) == 0) {
        printf("RAM filesystem unavailable, using disk storage\n");
        return 0;
    }
    
    return -1;  // All methods failed
}

static int create_temp_directory(char *temp_dir) {
    if (use_ram_filesystem) {
        // Try RAM filesystem first
        if (create_ram_filesystem(temp_dir) == 0) {
            return 0;
        }
        // If RAM filesystem failed, we already have a directory created
        // Just continue using it as a regular temp dir
        use_ram_filesystem = 0;
        printf("Using temporary directory at %s\n", temp_dir);
        return 0;
    }
    
    // Regular temporary directory fallback
    if (mkdtemp(temp_dir) == NULL) {
        fprintf(stderr, "Error: Cannot create temporary directory: %s\n", strerror(errno));
        return -1;
    }
    
    printf("Created temporary directory at %s\n", temp_dir);
    return 0;
}

// Memory file support for memfd_create
#define MAX_MEMFD_FILES 1024

typedef struct {
    char name[MAX_PATH];
    int fd;
    size_t size;
    int used;
} MemfdFile;

static MemfdFile memfd_files[MAX_MEMFD_FILES];
static int memfd_count = 0;

static int create_memfd_file(const char *relative_path, const void *data, size_t size) {
    if (memfd_count >= MAX_MEMFD_FILES || ram_method != 1) {
        return -1;  // Not using memfd or too many files
    }
    
#ifdef __linux__
    // Create memory-backed file
    char name[256];
    snprintf(name, sizeof(name), "sscc_%s", strrchr(relative_path, '/') ? strrchr(relative_path, '/') + 1 : relative_path);
    
    int fd = memfd_create(name, MFD_CLOEXEC);
    if (fd < 0) {
        return -1;
    }
    
    // Set size and write data
    if (ftruncate(fd, size) < 0 || write(fd, data, size) != (ssize_t)size) {
        close(fd);
        return -1;
    }
    
    // Reset file position
    lseek(fd, 0, SEEK_SET);
    
    // Store file info
    strncpy(memfd_files[memfd_count].name, relative_path, MAX_PATH - 1);
    memfd_files[memfd_count].name[MAX_PATH - 1] = '\0';
    memfd_files[memfd_count].fd = fd;
    memfd_files[memfd_count].size = size;
    memfd_files[memfd_count].used = 1;
    
    return memfd_count++;
#else
    return -1;
#endif
}

// Forward declaration
static int create_directory_recursive(const char *path);

static int create_memfd_files(const char *temp_dir) {
    if (ram_method != 1) return 0;
    
    // For TCC compatibility, create regular files from memfd content instead of symlinks
    for (int i = 0; i < memfd_count; i++) {
        if (!memfd_files[i].used) continue;
        
        char file_path[MAX_PATH];
        snprintf(file_path, sizeof(file_path), "%s/%s", temp_dir, memfd_files[i].name);
        
        // Create parent directories
        char *last_slash = strrchr(file_path, '/');
        if (last_slash && last_slash != file_path) {
            *last_slash = '\0';
            create_directory_recursive(file_path);
            *last_slash = '/';
        }
        
        // Read data from memfd and write to regular file
        lseek(memfd_files[i].fd, 0, SEEK_SET);
        char *buffer = malloc(memfd_files[i].size);
        if (buffer && read(memfd_files[i].fd, buffer, memfd_files[i].size) == (ssize_t)memfd_files[i].size) {
            FILE *f = fopen(file_path, "wb");
            if (f) {
                fwrite(buffer, 1, memfd_files[i].size, f);
                fclose(f);
            }
        }
        if (buffer) free(buffer);
    }
    
    return 0;
}

static void cleanup_memfd_files() {
    if (ram_method != 1) return;
    
    for (int i = 0; i < memfd_count; i++) {
        if (memfd_files[i].used && memfd_files[i].fd >= 0) {
            close(memfd_files[i].fd);
            memfd_files[i].used = 0;
        }
    }
    memfd_count = 0;
}

static void track_file_size(const char *path, size_t size) {
    total_ram_used += size;
    // Only track totals, don't print individual file info
}

static uint32_t read_uint32(const char **data) {
    uint32_t val = *(uint32_t*)*data;
    *data += sizeof(uint32_t);
    return val;
}

static int lzma_decompress_data(const char *input, size_t input_size, char *output, size_t output_size) {
    lzma_stream strm = LZMA_STREAM_INIT;
    
    lzma_ret ret = lzma_stream_decoder(&strm, UINT64_MAX, LZMA_CONCATENATED);
    if (ret != LZMA_OK) return -1;
    
    strm.next_in = (const uint8_t*)input;
    strm.avail_in = input_size;
    strm.next_out = (uint8_t*)output;
    strm.avail_out = output_size;
    
    ret = lzma_code(&strm, LZMA_FINISH);
    lzma_end(&strm);
    
    return (ret == LZMA_STREAM_END) ? 0 : -1;
}

static int create_directory_recursive(const char *path) {
    char *path_copy = strdup(path);
    char *p = path_copy;
    
    while ((p = strchr(p + 1, '/')) != NULL) {
        *p = '\0';
        if (mkdir(path_copy, 0755) != 0 && errno != EEXIST) {
            fprintf(stderr, "Error: Cannot create directory %s: %s\n", path_copy, strerror(errno));
            free(path_copy);
            return -1;
        }
        *p = '/';
    }
    
    if (mkdir(path_copy, 0755) != 0 && errno != EEXIST) {
        fprintf(stderr, "Error: Cannot create directory %s: %s\n", path_copy, strerror(errno));
        free(path_copy);
        return -1;
    }
    
    free(path_copy);
    return 0;
}

static int extract_core_archive(const char *archive_data, size_t archive_size, const char *temp_dir) {
    const char *data = archive_data;
    
    if (memcmp(data, "CORE", 4) != 0) {
        fprintf(stderr, "Error: Invalid core archive format\n");
        return -1;
    }
    data += 4;
    
    uint32_t file_count = read_uint32(&data);
    size_t core_ram_used = 0;
    
    for (uint32_t i = 0; i < file_count; i++) {
        uint32_t path_len = read_uint32(&data);
        char path[MAX_PATH];
        memcpy(path, data, path_len);
        path[path_len] = '\0';
        data += path_len;
        
        uint32_t original_size = read_uint32(&data);
        uint32_t compressed_size = read_uint32(&data);
        
        char *decompressed = malloc(original_size);
        if (!decompressed) {
            fprintf(stderr, "Error: Memory allocation failed\n");
            return -1;
        }
        
        if (lzma_decompress_data(data, compressed_size, decompressed, original_size) != 0) {
            fprintf(stderr, "Error: Failed to decompress core file %s\n", path);
            free(decompressed);
            return -1;
        }
        
        // Try memfd first, fallback to regular file
        if (ram_method == 1) {
            int memfd_id = create_memfd_file(path, decompressed, original_size);
            if (memfd_id >= 0) {
                track_file_size(path, original_size);
                core_ram_used += original_size;
                free(decompressed);
                data += compressed_size;
                continue;
            }
        }
        
        // Regular file creation (for /dev/shm, tmpfs, or disk)
        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", temp_dir, path);
        
        char *last_slash = strrchr(full_path, '/');
        if (last_slash) {
            *last_slash = '\0';
            create_directory_recursive(full_path);
            *last_slash = '/';
        }
        
        FILE *f = fopen(full_path, "wb");
        if (!f) {
            fprintf(stderr, "Error: Cannot create file %s\n", full_path);
            free(decompressed);
            return -1;
        }
        
        fwrite(decompressed, 1, original_size, f);
        fclose(f);
        
        // Track RAM usage for this file
        track_file_size(full_path, original_size);
        core_ram_used += original_size;
        
        free(decompressed);
        data += compressed_size;
    }
    
    // Create files for memfd files
    if (ram_method == 1) {
        create_memfd_files(temp_dir);
    }
    
    // Show core summary like addon loading
    char core_size_str[64];
    format_bytes(core_ram_used, core_size_str, sizeof(core_size_str));
    printf("Loading core 'musl': Complete C standard library (%u files)\n", file_count);
    printf("Core 'musl' loaded: %s in RAM\n", core_size_str);
    
    return 0;
}

static int load_addon_file(const char *addon_path, const char *temp_dir) {
    FILE *f = fopen(addon_path, "rb");
    if (!f) {
        fprintf(stderr, "Warning: Cannot open addon file %s\n", addon_path);
        return -1;
    }
    
    // Read magic
    char magic[6];
    if (fread(magic, 1, 5, f) != 5 || memcmp(magic, "ADDON", 5) != 0) {
        fprintf(stderr, "Warning: Invalid addon file format: %s\n", addon_path);
        fclose(f);
        return -1;
    }
    
    // Read addon name
    uint32_t name_len;
    fread(&name_len, sizeof(uint32_t), 1, f);
    char *addon_name = malloc(name_len + 1);
    fread(addon_name, 1, name_len, f);
    addon_name[name_len] = '\0';
    
    // Read description
    uint32_t desc_len;
    fread(&desc_len, sizeof(uint32_t), 1, f);
    char *description = malloc(desc_len + 1);
    fread(description, 1, desc_len, f);
    description[desc_len] = '\0';
    
    // Read file count
    uint32_t file_count;
    fread(&file_count, sizeof(uint32_t), 1, f);
    
    printf("Loading addon '%s': %s (%u files)\n", addon_name, description, file_count);
    
    size_t addon_ram_used = 0;
    
    // Extract files
    for (uint32_t i = 0; i < file_count; i++) {
        uint32_t path_len;
        fread(&path_len, sizeof(uint32_t), 1, f);
        
        char path[MAX_PATH];
        fread(path, 1, path_len, f);
        path[path_len] = '\0';
        
        uint32_t original_size, compressed_size;
        fread(&original_size, sizeof(uint32_t), 1, f);
        fread(&compressed_size, sizeof(uint32_t), 1, f);
        
        char *compressed_data = malloc(compressed_size);
        fread(compressed_data, 1, compressed_size, f);
        
        char *decompressed = malloc(original_size);
        if (lzma_decompress_data(compressed_data, compressed_size, decompressed, original_size) == 0) {
            // Try memfd first for addons too
            if (ram_method == 1) {
                int memfd_id = create_memfd_file(path, decompressed, original_size);
                if (memfd_id >= 0) {
                    track_file_size(path, original_size);
                    addon_ram_used += original_size;
                    free(compressed_data);
                    free(decompressed);
                    continue;
                }
            }
            
            // Regular file creation
            char full_path[MAX_PATH];
            snprintf(full_path, sizeof(full_path), "%s/%s", temp_dir, path);
            
            char *last_slash = strrchr(full_path, '/');
            if (last_slash) {
                *last_slash = '\0';
                create_directory_recursive(full_path);
                *last_slash = '/';
            }
            
            FILE *out = fopen(full_path, "wb");
            if (out) {
                fwrite(decompressed, 1, original_size, out);
                fclose(out);
                
                // Track RAM usage for this addon file
                track_file_size(full_path, original_size);
                addon_ram_used += original_size;
            }
        }
        
        free(compressed_data);
        free(decompressed);
    }
    
    // Show addon summary
    if (use_ram_filesystem && addon_ram_used > 0) {
        char addon_size_str[64];
        format_bytes(addon_ram_used, addon_size_str, sizeof(addon_size_str));
        printf("Addon '%s' loaded: %s in RAM\n", addon_name, addon_size_str);
    }
    
    free(addon_name);
    free(description);
    fclose(f);
    return 0;
}

static void load_addons(const char *temp_dir, char **addon_files, int addon_count) {
    // Load explicitly specified addon files only
    for (int i = 0; i < addon_count; i++) {
        load_addon_file(addon_files[i], temp_dir);
    }
    
    // Create files for memfd addon files
    if (ram_method == 1) {
        create_memfd_files(temp_dir);
    }
}

static void cleanup_temp_dir(const char *temp_dir) {
    if (use_ram_filesystem) {
        // Cleanup memfd files
        cleanup_memfd_files();
    }
    
    // Remove the directory (works for all methods)
    char cmd[MAX_PATH + 20];
    snprintf(cmd, sizeof(cmd), "rm -rf %s", temp_dir);
    system(cmd);
}

// External symbols for embedded core archive and TCC binary
extern const unsigned char sscc_archive_data[];
extern const unsigned int sscc_archive_size;
extern const unsigned char tcc_binary_data[];
extern const unsigned int tcc_binary_size;
int main(int argc, char *argv[]) {
    char *addon_files[64] = {0};
    int addon_count = 0;
    char **filtered_args = malloc(argc * sizeof(char*));
    int filtered_argc = 0;
    
    // Parse arguments
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            printf("SSCC v%s - Self Sufficient C Compiler\n", SSCC_VERSION);
            printf("A portable, modular C compiler with addon support\n");
            printf("\n");
            printf("Usage: sscc [options] file...\n");
            printf("\n");
            printf("Modular options:\n");
            printf("  --addon FILE    Load addon file (.addon)\n");
            printf("\n");
            printf("Common options:\n");
            printf("  -o FILE         Output to FILE\n");
            printf("  -v, --version   Show version information\n");
            printf("  -h, --help      Show this help message\n");
            printf("  -g              Include debug information\n");
            printf("  -O              Optimize code\n");
            printf("  -Wall           Enable warnings\n");
            printf("  -I DIR          Add include directory\n");
            printf("  -L DIR          Add library directory\n");
            printf("  -l LIB          Link with library\n");
            printf("\n");
            return 0;
        } else if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--version") == 0) {
            printf("SSCC v%s - Self Sufficient C Compiler\n", SSCC_VERSION);
            printf("Built with complete musl libc and TCC compiler integration\n");
            printf("Core size: %u files, TCC binary: %u bytes\n", 
                   sscc_archive_size > 0 ? 228 : 0, tcc_binary_size);
            printf("\n");
            printf("Features:\n");
            printf("  • Complete C99/C11 standard library\n");
            printf("  • Static linking with musl libc\n");
            printf("  • RAM-based compilation (memfd/shm)\n");
            printf("  • Modular addon system\n");
            printf("  • Single portable binary\n");
            printf("\n");
            printf("Copyright (c) 2025 SSCC Project\n");
            printf("License: Open source (see documentation)\n");
            return 0;
        } else if (strcmp(argv[i], "--addon") == 0 && i + 1 < argc) {
            addon_files[addon_count++] = argv[i + 1];
            i++; // Skip the addon file argument
        } else {
            filtered_args[filtered_argc++] = argv[i];
        }
    }
    
    // Create temporary directory (RAM filesystem if possible)
    char temp_dir[MAX_PATH];
    char *temp_template = get_temp_dir_template();
    strcpy(temp_dir, temp_template);
    if (create_temp_directory(temp_dir) != 0) {
        fprintf(stderr, "Error: Cannot create temporary directory\n");
        free(filtered_args);
        return 1;
    }
    
    printf("SSCC - Modular C Compiler\n");
    
    // Extract core archive
    if (extract_core_archive((const char*)sscc_archive_data, sscc_archive_size, temp_dir) != 0) {
        fprintf(stderr, "Error: Failed to extract core resources\n");
        cleanup_temp_dir(temp_dir);
        free(filtered_args);
        return 1;
    }
    
    // Extract embedded TCC binary
    char tcc_path[MAX_PATH];
    snprintf(tcc_path, sizeof(tcc_path), "%s/tcc", temp_dir);
    FILE *tcc_file = fopen(tcc_path, "wb");
    if (!tcc_file) {
        fprintf(stderr, "Error: Cannot create TCC binary at %s\n", tcc_path);
        cleanup_temp_dir(temp_dir);
        free(filtered_args);
        return 1;
    }
    fwrite(tcc_binary_data, 1, tcc_binary_size, tcc_file);
    fclose(tcc_file);
    chmod(tcc_path, 0755); // Make executable
    
    // Track TCC binary size
    track_file_size(tcc_path, tcc_binary_size);
    
    // Load addons (only explicitly specified ones)
    load_addons(temp_dir, addon_files, addon_count);
    
    // Show total RAM usage before compilation
    if (use_ram_filesystem) {
        char total_str[64];
        format_bytes(total_ram_used, total_str, sizeof(total_str));
        
        const char* method_name = "";
        switch (ram_method) {
            case 1: method_name = " (memfd)"; break;
            case 2: method_name = " (/dev/shm)"; break;
            case 3: method_name = " (disk)"; break;
        }
        printf("Total cached size: %s%s\n", total_str, method_name);
    }
    
    // TCC binary is now extracted to temp directory
    // (No need to look for external sscc.bin file)
    
    // Prepare arguments for TCC
    char **tcc_args = malloc((filtered_argc + 10) * sizeof(char*));
    int arg_count = 0;
    
    tcc_args[arg_count++] = tcc_path;
    
    char include_path[MAX_PATH];
    char lib_path[MAX_PATH];
    snprintf(include_path, sizeof(include_path), "-I%s/include", temp_dir);
    snprintf(lib_path, sizeof(lib_path), "-L%s/lib", temp_dir);
    
    tcc_args[arg_count++] = include_path;
    tcc_args[arg_count++] = lib_path;
    
    char b_path[MAX_PATH];
    snprintf(b_path, sizeof(b_path), "-B%s/lib", temp_dir);
    tcc_args[arg_count++] = b_path;
    tcc_args[arg_count++] = "-static";
    
    // Copy remaining arguments
    for (int i = 1; i < filtered_argc; i++) {
        tcc_args[arg_count++] = filtered_args[i];
    }
    tcc_args[arg_count] = NULL;
    
    printf("Starting compilation...\n");
    
    // Fork and execute TCC so we can cleanup afterwards
    pid_t pid = fork();
    if (pid == 0) {
        // Child process: execute TCC
        execv(tcc_path, tcc_args);
        // If we get here, execv failed
        fprintf(stderr, "Error: Failed to execute TCC: %s\n", strerror(errno));
        exit(1);
    } else if (pid > 0) {
        // Parent process: wait for TCC to finish
        int status;
        wait(&status);
        
        // Cleanup and show total
        cleanup_temp_dir(temp_dir);
        
        free(filtered_args);
        free(tcc_args);
        
        // Return TCC's exit status
        return WEXITSTATUS(status);
    } else {
        // Fork failed
        fprintf(stderr, "Error: Failed to fork process: %s\n", strerror(errno));
        cleanup_temp_dir(temp_dir);
        free(filtered_args);
        free(tcc_args);
        return 1;
    }
}
