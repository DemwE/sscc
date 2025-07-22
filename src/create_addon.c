// SSCC Addon Creator - Creates modular addon files for extended functionality
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdint.h>
#include <lzma.h>

#define MAX_PATH 4096
#define MAX_CORE_FILES 1024

// Dynamic core files list (loaded from embedded archive)
static char core_files[MAX_CORE_FILES][MAX_PATH];
static int core_file_count = 0;

// External symbols for embedded core archive (same as in sscc.c)
extern const unsigned char sscc_archive_data[];
extern const unsigned int sscc_archive_size;

static uint32_t read_uint32(const char **data) {
    uint32_t val = *(uint32_t*)*data;
    *data += sizeof(uint32_t);
    return val;
}

static int load_core_files_from_archive() {
    const char *data = (const char*)sscc_archive_data;
    
    if (!data || sscc_archive_size < 8) {
        fprintf(stderr, "Warning: No embedded core archive found, using minimal exclusions\n");
        // Fallback to basic exclusions
        strcpy(core_files[0], "libc.a");
        strcpy(core_files[1], "libm.a");
        strcpy(core_files[2], "libtcc1.a");
        core_file_count = 3;
        return 0;
    }
    
    if (memcmp(data, "CORE", 4) != 0) {
        fprintf(stderr, "Warning: Invalid core archive format\n");
        return -1;
    }
    data += 4;
    
    uint32_t file_count = read_uint32(&data);
    printf("Loading core file list from embedded archive (%u files)...\n", file_count);
    
    core_file_count = 0;
    for (uint32_t i = 0; i < file_count && core_file_count < MAX_CORE_FILES; i++) {
        uint32_t path_len = read_uint32(&data);
        if (path_len >= MAX_PATH) {
            fprintf(stderr, "Warning: Path too long in core archive\n");
            return -1;
        }
        
        // Extract just the filename for comparison
        char full_path[MAX_PATH];
        memcpy(full_path, data, path_len);
        full_path[path_len] = '\0';
        data += path_len;
        
        // Store the full path for exclusion
        strcpy(core_files[core_file_count], full_path);
        core_file_count++;
        
        // Skip the file data
        uint32_t original_size = read_uint32(&data);
        uint32_t compressed_size = read_uint32(&data);
        data += compressed_size;
        
        (void)original_size; // Suppress unused warning
    }
    
    printf("Loaded %d core files for exclusion from addons\n", core_file_count);
    return 0;
}

static int is_core_file(const char* filename) {
    // Check against dynamically loaded core files
    for (int i = 0; i < core_file_count; i++) {
        // Check if the file path contains this core file
        if (strstr(filename, core_files[i]) || strstr(core_files[i], filename)) {
            return 1;
        }
    }
    return 0;
}

static int lzma_compress_data(const char *input, size_t input_size, char **output, size_t *output_size) {
    lzma_stream strm = LZMA_STREAM_INIT;
    
    lzma_ret ret = lzma_easy_encoder(&strm, 9, LZMA_CHECK_CRC64);
    if (ret != LZMA_OK) return -1;
    
    *output_size = input_size + (input_size / 3) + 128;
    *output = malloc(*output_size);
    if (!*output) {
        lzma_end(&strm);
        return -1;
    }
    
    strm.next_in = (const uint8_t*)input;
    strm.avail_in = input_size;
    strm.next_out = (uint8_t*)*output;
    strm.avail_out = *output_size;
    
    ret = lzma_code(&strm, LZMA_FINISH);
    if (ret != LZMA_STREAM_END) {
        free(*output);
        lzma_end(&strm);
        return -1;
    }
    
    *output_size = strm.total_out;
    lzma_end(&strm);
    return 0;
}

static void scan_and_add_files(const char* dir_path, const char* prefix, FILE* addon, uint32_t* file_count) {
    DIR* dir = opendir(dir_path);
    if (!dir) return;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        
        char full_path[MAX_PATH];
        snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, entry->d_name);
        
        struct stat st;
        if (stat(full_path, &st) != 0) continue;
        
        if (S_ISDIR(st.st_mode)) {
            char new_prefix[MAX_PATH];
            snprintf(new_prefix, sizeof(new_prefix), "%s%s%s", prefix, strlen(prefix) ? "/" : "", entry->d_name);
            scan_and_add_files(full_path, new_prefix, addon, file_count);
        } else if (S_ISREG(st.st_mode)) {
            char rel_path[MAX_PATH];
            snprintf(rel_path, sizeof(rel_path), "%s%s%s", prefix, strlen(prefix) ? "/" : "", entry->d_name);
            
            // Skip core files
            if (is_core_file(entry->d_name)) {
                continue;
            }
            
            FILE* f = fopen(full_path, "rb");
            if (!f) continue;
            
            fseek(f, 0, SEEK_END);
            long file_size = ftell(f);
            fseek(f, 0, SEEK_SET);
            
            if (file_size > 2*1024*1024) { // Skip files larger than 2MB
                fclose(f);
                continue;
            }
            
            char* file_data = malloc(file_size);
            if (!file_data) {
                fclose(f);
                continue;
            }
            
            if (fread(file_data, 1, file_size, f) != file_size) {
                fclose(f);
                free(file_data);
                continue;
            }
            fclose(f);
            
            char* compressed_data;
            size_t compressed_size;
            if (lzma_compress_data(file_data, file_size, &compressed_data, &compressed_size) == 0) {
                uint32_t path_len = strlen(rel_path);
                uint32_t original_size = file_size;
                uint32_t comp_size = compressed_size;
                
                fwrite(&path_len, sizeof(uint32_t), 1, addon);
                fwrite(rel_path, 1, path_len, addon);
                fwrite(&original_size, sizeof(uint32_t), 1, addon);
                fwrite(&comp_size, sizeof(uint32_t), 1, addon);
                fwrite(compressed_data, 1, compressed_size, addon);
                
                (*file_count)++;
                printf("  %s (%ld -> %zu bytes, %.1f%%)\n", 
                       rel_path, file_size, compressed_size, 
                       (float)compressed_size / file_size * 100);
                
                free(compressed_data);
            }
            free(file_data);
        }
    }
    closedir(dir);
}

int main(int argc, char* argv[]) {
    if (argc != 6) {
        fprintf(stderr, "Usage: %s <addon_name> <description> <include_dir> <lib_dir> <output.addon>\n", argv[0]);
        fprintf(stderr, "Example: %s libextra \"Extended musl libraries\" include lib sscc-libextra.addon\n", argv[0]);
        return 1;
    }
    
    // Load core files from embedded archive for automatic exclusion
    if (load_core_files_from_archive() != 0) {
        fprintf(stderr, "Warning: Could not load core files list, proceeding with minimal exclusions\n");
    }
    
    const char* addon_name = argv[1];
    const char* description = argv[2];
    const char* include_dir = argv[3];
    const char* lib_dir = argv[4];
    const char* output_file = argv[5];
    
    FILE* addon = fopen(output_file, "wb");
    if (!addon) {
        perror("Cannot create addon file");
        return 1;
    }
    
    printf("Creating addon: %s\n", addon_name);
    printf("Description: %s\n", description);
    
    // Write magic
    fwrite("ADDON", 5, 1, addon);
    
    // Write addon name
    uint32_t name_len = strlen(addon_name);
    fwrite(&name_len, sizeof(uint32_t), 1, addon);
    fwrite(addon_name, 1, name_len, addon);
    
    // Write description
    uint32_t desc_len = strlen(description);
    fwrite(&desc_len, sizeof(uint32_t), 1, addon);
    fwrite(description, 1, desc_len, addon);
    
    // Placeholder for file count
    long count_pos = ftell(addon);
    uint32_t file_count = 0;
    fwrite(&file_count, sizeof(uint32_t), 1, addon);
    
    // Add files from include directory
    if (access(include_dir, F_OK) == 0) {
        printf("Adding headers from %s:\n", include_dir);
        scan_and_add_files(include_dir, "include", addon, &file_count);
    }
    
    // Add files from lib directory
    if (access(lib_dir, F_OK) == 0) {
        printf("Adding libraries from %s:\n", lib_dir);
        scan_and_add_files(lib_dir, "lib", addon, &file_count);
    }
    
    // Write actual file count
    fseek(addon, count_pos, SEEK_SET);
    fwrite(&file_count, sizeof(uint32_t), 1, addon);
    
    fclose(addon);
    
    struct stat st;
    stat(output_file, &st);
    printf("\nAddon created: %u files, %ld bytes\n", file_count, st.st_size);
    printf("File: %s\n", output_file);
    
    return 0;
}
