#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <stdint.h>
#include <errno.h>
#include <libgen.h>
#include <glob.h>
#include <lzma.h>

#define MAX_PATH 4096
#define TEMP_DIR_TEMPLATE "/tmp/sscc_XXXXXX"

static char* get_temp_dir_template() {
    const char* tmpdir = getenv("TMPDIR");
    if (tmpdir == NULL) tmpdir = getenv("TEMP");
    if (tmpdir == NULL) tmpdir = "/tmp";
    
    static char template_buf[MAX_PATH];
    snprintf(template_buf, sizeof(template_buf), "%s/sscc_XXXXXX", tmpdir);
    return template_buf;
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
    printf("Extracting core: %u files...\n", file_count);
    
    for (uint32_t i = 0; i < file_count; i++) {
        uint32_t path_len = read_uint32(&data);
        char path[MAX_PATH];
        memcpy(path, data, path_len);
        path[path_len] = '\0';
        data += path_len;
        
        uint32_t original_size = read_uint32(&data);
        uint32_t compressed_size = read_uint32(&data);
        
        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", temp_dir, path);
        
        printf("Extracting: %s -> %s\n", path, full_path);
        
        char *last_slash = strrchr(full_path, '/');
        if (last_slash) {
            *last_slash = '\0';
            create_directory_recursive(full_path);
            *last_slash = '/';
        }
        
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
        
        FILE *f = fopen(full_path, "wb");
        if (!f) {
            fprintf(stderr, "Error: Cannot create file %s\n", full_path);
            free(decompressed);
            return -1;
        }
        
        fwrite(decompressed, 1, original_size, f);
        fclose(f);
        free(decompressed);
        
        data += compressed_size;
    }
    
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
        
        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", temp_dir, path);
        
        char *last_slash = strrchr(full_path, '/');
        if (last_slash) {
            *last_slash = '\0';
            create_directory_recursive(full_path);
            *last_slash = '/';
        }
        
        char *decompressed = malloc(original_size);
        if (lzma_decompress_data(compressed_data, compressed_size, decompressed, original_size) == 0) {
            FILE *out = fopen(full_path, "wb");
            if (out) {
                fwrite(decompressed, 1, original_size, out);
                fclose(out);
            }
        }
        
        free(compressed_data);
        free(decompressed);
    }
    
    free(addon_name);
    free(description);
    fclose(f);
    return 0;
}

static void load_addons(const char *temp_dir, char **addon_files, int addon_count) {
    // Load explicitly specified addon files
    for (int i = 0; i < addon_count; i++) {
        load_addon_file(addon_files[i], temp_dir);
    }
    
    // Auto-discover addon files in current directory
    glob_t glob_result;
    if (glob("sscc-*.addon", GLOB_NOSORT, NULL, &glob_result) == 0) {
        for (size_t i = 0; i < glob_result.gl_pathc; i++) {
            // Check if this addon was already loaded explicitly
            int already_loaded = 0;
            for (int j = 0; j < addon_count; j++) {
                if (strcmp(glob_result.gl_pathv[i], addon_files[j]) == 0) {
                    already_loaded = 1;
                    break;
                }
            }
            
            if (!already_loaded) {
                load_addon_file(glob_result.gl_pathv[i], temp_dir);
            }
        }
        globfree(&glob_result);
    }
}

static void cleanup_temp_dir(const char *temp_dir) {
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
            printf("SSCC - Self Sufficient C Compiler\n");
            printf("A portable, modular C compiler with addon support\n");
            printf("\n");
            printf("Usage: sscc [options] file...\n");
            printf("\n");
            printf("Modular options:\n");
            printf("  --addon FILE    Load addon file (.addon)\n");
            printf("  --list-addons   List available addons in current directory\n");
            printf("\n");
            printf("Common options:\n");
            printf("  -o FILE         Output to FILE\n");
            printf("  -v              Show version\n");
            printf("  -g              Include debug information\n");
            printf("  -O              Optimize code\n");
            printf("  -Wall           Enable warnings\n");
            printf("  -I DIR          Add include directory\n");
            printf("  -L DIR          Add library directory\n");
            printf("  -l LIB          Link with library\n");
            printf("\n");
            printf("Core features (always available):\n");
            printf("  • Essential C standard library headers\n");
            printf("  • Basic libc and libm\n");
            printf("  • TCC runtime library\n");
            printf("\n");
            printf("Available addons (load as needed):\n");
            printf("  • sscc-gmp.addon      - GNU Multiple Precision arithmetic\n");
            printf("  • sscc-posix.addon    - POSIX system calls and threading\n");
            printf("  • sscc-network.addon  - Network programming support\n");
            printf("\n");
            return 0;
        } else if (strcmp(argv[i], "--list-addons") == 0) {
            printf("Available addon files:\n");
            glob_t glob_result;
            if (glob("sscc-*.addon", GLOB_NOSORT, NULL, &glob_result) == 0) {
                for (size_t j = 0; j < glob_result.gl_pathc; j++) {
                    struct stat st;
                    stat(glob_result.gl_pathv[j], &st);
                    printf("  %-20s (%ld bytes)\n", glob_result.gl_pathv[j], st.st_size);
                }
                globfree(&glob_result);
            } else {
                printf("  No addon files found in current directory\n");
            }
            return 0;
        } else if (strcmp(argv[i], "--addon") == 0 && i + 1 < argc) {
            addon_files[addon_count++] = argv[i + 1];
            i++; // Skip the addon file argument
        } else {
            filtered_args[filtered_argc++] = argv[i];
        }
    }
    
    // Create temporary directory
    char *temp_template = get_temp_dir_template();
    char temp_dir[MAX_PATH];
    strcpy(temp_dir, temp_template);
    if (mkdtemp(temp_dir) == NULL) {
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
    
    // Load addons (always attempt auto-discovery)
    load_addons(temp_dir, addon_files, addon_count);
    
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
    
    free(filtered_args);
    
    // Execute TCC
    execv(tcc_path, tcc_args);
    
    // If we get here, execv failed
    fprintf(stderr, "Error: Failed to execute TCC: %s\n", strerror(errno));
    cleanup_temp_dir(temp_dir);
    return 1;
}
