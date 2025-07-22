#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s input_file output_file symbol_name\n", argv[0]);
        fprintf(stderr, "Example: %s core.bin core.c sscc_archive\n", argv[0]);
        return 1;
    }
    
    FILE *input = fopen(argv[1], "rb");
    if (!input) {
        perror("Cannot open input file");
        return 1;
    }
    
    FILE *output = fopen(argv[2], "w");
    if (!output) {
        perror("Cannot open output file");
        fclose(input);
        return 1;
    }
    
    const char *symbol_name = argv[3];
    
    // Get file size
    fseek(input, 0, SEEK_END);
    long file_size = ftell(input);
    fseek(input, 0, SEEK_SET);
    
    fprintf(output, "const unsigned char %s_data[] = {\n", symbol_name);
    
    int byte;
    int count = 0;
    int col = 0;
    
    while ((byte = fgetc(input)) != EOF) {
        if (col == 0) {
            fprintf(output, "  ");
        }
        
        fprintf(output, "0x%02x", byte);
        count++;
        col++;
        
        if (count < file_size) {
            fprintf(output, ",");
        }
        
        if (col >= 12) {
            fprintf(output, "\n");
            col = 0;
        } else if (count < file_size) {
            fprintf(output, " ");
        }
    }
    
    if (col > 0) {
        fprintf(output, "\n");
    }
    fprintf(output, "};\n");
    fprintf(output, "const unsigned int %s_size = %d;\n", symbol_name, count);
    
    fclose(input);
    fclose(output);
    
    printf("Converted %d bytes to C source with symbol '%s'\n", count, symbol_name);
    return 0;
}
