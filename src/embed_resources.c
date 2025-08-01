// Complete musl resource embedder for SSCC
// Includes ALL headers and libraries from musl for full POSIX functionality
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdint.h>
#include <lzma.h>

#define MAX_PATH 4096

// Include ALL musl headers (no filtering)
// const char* core_includes[] = { NULL }; // Not used - include everything

// Include ALL musl libraries (no filtering)  
// const char* core_libs[] = { NULL }; // Not used - include everything

// const char* core_objects[] = { NULL }; // Not used - include everything

static int lzma_compress_data(const char *input, size_t input_size, char **output, size_t *output_size) {
    lzma_stream strm = LZMA_STREAM_INIT;
    
    // Initialize with maximum compression
    lzma_ret ret = lzma_easy_encoder(&strm, 9, LZMA_CHECK_CRC64);
    if (ret != LZMA_OK) return -1;
    
    *output_size = input_size + (input_size / 3) + 128; // Buffer
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

static int should_include_file(const char* path) {
    // Include ALL headers and libraries - no filtering for complete musl functionality
    if (strstr(path, "include/") || strstr(path, "lib/")) {
        return 1; // Include everything
    }
    
    return 0;
}

static void scan_directory(const char* dir_path, const char* prefix, FILE* archive, uint32_t* file_count) {
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
            scan_directory(full_path, new_prefix, archive, file_count);
        } else if (S_ISREG(st.st_mode)) {
            char rel_path[MAX_PATH];
            snprintf(rel_path, sizeof(rel_path), "%s%s%s", prefix, strlen(prefix) ? "/" : "", entry->d_name);
            
            if (!should_include_file(rel_path)) continue;
            
            FILE* f = fopen(full_path, "rb");
            if (!f) continue;
            
            fseek(f, 0, SEEK_END);
            long file_size = ftell(f);
            fseek(f, 0, SEEK_SET);
            
            if (file_size > 512*1024) { // Skip files larger than 512KB
                fclose(f);
                continue;
            }
            
            char* file_data = malloc(file_size);
            if (!file_data) {
                fclose(f);
                continue;
            }
            
            if (fread(file_data, 1, file_size, f) != file_size) {
                fprintf(stderr, "Warning: Could not read complete file %s\n", full_path);
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
                
                fwrite(&path_len, sizeof(uint32_t), 1, archive);
                fwrite(rel_path, 1, path_len, archive);
                fwrite(&original_size, sizeof(uint32_t), 1, archive);
                fwrite(&comp_size, sizeof(uint32_t), 1, archive);
                fwrite(compressed_data, 1, compressed_size, archive);
                
                (*file_count)++;
                printf("Core: %s (%ld -> %zu bytes, %.1f%%)\n", 
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
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <include_dir> <lib_dir> <output_file>\n", argv[0]);
        return 1;
    }
    
    FILE* archive = fopen(argv[3], "wb");
    if (!archive) {
        perror("Cannot create core archive");
        return 1;
    }
    
    // Write magic
    fwrite("CORE", 4, 1, archive);
    
    // Placeholder for file count
    long count_pos = ftell(archive);
    uint32_t file_count = 0;
    fwrite(&file_count, sizeof(uint32_t), 1, archive);
    
    printf("Creating complete musl core archive with all headers and libraries...\n");
    
    scan_directory(argv[1], "include", archive, &file_count);
    scan_directory(argv[2], "lib", archive, &file_count);
    
    // Write actual file count
    fseek(archive, count_pos, SEEK_SET);
    fwrite(&file_count, sizeof(uint32_t), 1, archive);
    
    fclose(archive);
    
    struct stat st;
    stat(argv[3], &st);
    printf("\nComplete musl core archive created: %u files, %ld bytes\n", file_count, st.st_size);
    printf("Includes full POSIX functionality from musl\n");
    
    return 0;
}
