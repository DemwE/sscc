#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s input_file output_file\n", argv[0]);
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
    
    fprintf(output, "const unsigned char sscc_archive_data[] = {\n");
    
    int byte;
    int count = 0;
    while ((byte = fgetc(input)) != EOF) {
        if (count % 16 == 0) {
            if (count > 0) fprintf(output, "\n");
            fprintf(output, "  ");
        }
        fprintf(output, "0x%02x", byte);
        count++;
        if ((byte = fgetc(input)) != EOF) {
            ungetc(byte, input);
            fprintf(output, ", ");
        } else {
            break;
        }
    }
    
    fprintf(output, "\n};\n");
    fprintf(output, "const unsigned int sscc_archive_size = %d;\n", count);
    
    fclose(input);
    fclose(output);
    
    printf("Converted %d bytes to C source\n", count);
    return 0;
}
