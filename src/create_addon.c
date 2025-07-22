// Create addon files for modular deployment
// Allows users to add additional libraries as needed
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdint.h>
#include <lzma.h>

#define MAX_PATH 4096

typedef struct {
    const char* name;
    const char* description;
    const char** include_patterns;
    const char** lib_patterns;
} addon_spec_t;

// Include patterns for GMP addon
const char* gmp_includes[] = {
    "gmp.h", "gmpxx.h", NULL
};

const char* gmp_libs[] = {
    "libgmp.a", "libgmpxx.a", NULL
};

// Include patterns for POSIX addon
const char* posix_includes[] = {
    "time.h", "signal.h", "sys/wait.h", "sys/ipc.h", "sys/shm.h", 
    "sys/sem.h", "sys/msg.h", "pthread.h", "semaphore.h", 
    "sys/socket.h", "netinet/", "arpa/", NULL
};

const char* posix_libs[] = {
    "libpthread.a", "librt.a", "libdl.a", NULL
};

// Networking addon
const char* network_includes[] = {
    "netdb.h", "ifaddrs.h", "net/", "netinet/", "arpa/", NULL
};

const char* network_libs[] = {
    "libresolv.a", NULL
};

addon_spec_t addons[] = {
    {
        .name = "gmp",
        .description = "GNU Multiple Precision Arithmetic Library",
        .include_patterns = gmp_includes,
        .lib_patterns = gmp_libs
    },
    {
        .name = "posix",
        .description = "POSIX system calls and threading",
        .include_patterns = posix_includes,
        .lib_patterns = posix_libs
    },
    {
        .name = "network",
        .description = "Network programming libraries",
        .include_patterns = network_includes,
        .lib_patterns = network_libs
    },
    { NULL }
};

static int matches_pattern(const char* filename, const char** patterns) {
    for (int i = 0; patterns[i]; i++) {
        if (strstr(filename, patterns[i])) {
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

static int should_include_file(const char* path, const addon_spec_t* addon) {
    const char* filename = strrchr(path, '/');
    if (filename) filename++;
    else filename = path;
    
    if (strstr(path, "include/")) {
        return matches_pattern(filename, addon->include_patterns);
    }
    
    if (strstr(path, "lib/")) {
        return matches_pattern(filename, addon->lib_patterns);
    }
    
    return 0;
}

static void scan_directory(const char* dir_path, const char* prefix, FILE* archive, 
                          uint32_t* file_count, const addon_spec_t* addon) {
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
            scan_directory(full_path, new_prefix, archive, file_count, addon);
        } else if (S_ISREG(st.st_mode)) {
            char rel_path[MAX_PATH];
            snprintf(rel_path, sizeof(rel_path), "%s%s%s", prefix, strlen(prefix) ? "/" : "", entry->d_name);
            
            if (!should_include_file(rel_path, addon)) continue;
            
            FILE* f = fopen(full_path, "rb");
            if (!f) continue;
            
            fseek(f, 0, SEEK_END);
            long file_size = ftell(f);
            fseek(f, 0, SEEK_SET);
            
            char* file_data = malloc(file_size);
            if (!file_data) {
                fclose(f);
                continue;
            }
            
            fread(file_data, 1, file_size, f);
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
    if (argc < 3) {
        printf("Usage: %s <include_dir> <lib_dir> [addon_name]\n\n", argv[0]);
        printf("Available addons:\n");
        for (int i = 0; addons[i].name; i++) {
            printf("  %-10s - %s\n", addons[i].name, addons[i].description);
        }
        return 1;
    }
    
    const char* include_dir = argv[1];
    const char* lib_dir = argv[2];
    const char* addon_name = argc > 3 ? argv[3] : "all";
    
    // Find addon
    addon_spec_t* target_addon = NULL;
    if (strcmp(addon_name, "all") != 0) {
        for (int i = 0; addons[i].name; i++) {
            if (strcmp(addons[i].name, addon_name) == 0) {
                target_addon = &addons[i];
                break;
            }
        }
        if (!target_addon) {
            printf("Unknown addon: %s\n", addon_name);
            return 1;
        }
    }
    
    if (target_addon) {
        // Create single addon
        char output_file[256];
        snprintf(output_file, sizeof(output_file), "sscc-%s.addon", target_addon->name);
        
        FILE* archive = fopen(output_file, "wb");
        if (!archive) {
            perror("Cannot create addon file");
            return 1;
        }
        
        // Write magic and metadata
        fwrite("ADDON", 5, 1, archive);
        uint32_t name_len = strlen(target_addon->name);
        fwrite(&name_len, sizeof(uint32_t), 1, archive);
        fwrite(target_addon->name, 1, name_len, archive);
        
        uint32_t desc_len = strlen(target_addon->description);
        fwrite(&desc_len, sizeof(uint32_t), 1, archive);
        fwrite(target_addon->description, 1, desc_len, archive);
        
        // Placeholder for file count
        long count_pos = ftell(archive);
        uint32_t file_count = 0;
        fwrite(&file_count, sizeof(uint32_t), 1, archive);
        
        printf("Creating %s addon...\n", target_addon->name);
        
        scan_directory(include_dir, "include", archive, &file_count, target_addon);
        scan_directory(lib_dir, "lib", archive, &file_count, target_addon);
        
        // Write actual file count
        fseek(archive, count_pos, SEEK_SET);
        fwrite(&file_count, sizeof(uint32_t), 1, archive);
        
        fclose(archive);
        
        struct stat st;
        stat(output_file, &st);
        printf("Created %s: %u files, %ld bytes\n", output_file, file_count, st.st_size);
    } else {
        // Create all addons
        printf("Creating all addon files...\n\n");
        for (int i = 0; addons[i].name; i++) {
            char output_file[256];
            snprintf(output_file, sizeof(output_file), "sscc-%s.addon", addons[i].name);
            
            FILE* archive = fopen(output_file, "wb");
            if (!archive) continue;
            
            // Write magic and metadata
            fwrite("ADDON", 5, 1, archive);
            uint32_t name_len = strlen(addons[i].name);
            fwrite(&name_len, sizeof(uint32_t), 1, archive);
            fwrite(addons[i].name, 1, name_len, archive);
            
            uint32_t desc_len = strlen(addons[i].description);
            fwrite(&desc_len, sizeof(uint32_t), 1, archive);
            fwrite(addons[i].description, 1, desc_len, archive);
            
            long count_pos = ftell(archive);
            uint32_t file_count = 0;
            fwrite(&file_count, sizeof(uint32_t), 1, archive);
            
            printf("%s addon:\n", addons[i].name);
            
            scan_directory(include_dir, "include", archive, &file_count, &addons[i]);
            scan_directory(lib_dir, "lib", archive, &file_count, &addons[i]);
            
            fseek(archive, count_pos, SEEK_SET);
            fwrite(&file_count, sizeof(uint32_t), 1, archive);
            
            fclose(archive);
            
            struct stat st;
            stat(output_file, &st);
            printf("  -> %s: %u files, %ld bytes\n\n", output_file, file_count, st.st_size);
        }
    }
    
    return 0;
}
