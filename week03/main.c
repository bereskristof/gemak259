#include "main.h"

int main(int argc, char* argv[]) {
    const char* fileName = GetFileName(argc, argv);
    FILE* file = fopen64(fileName, "rb");
    free((void*)fileName);
    if (file == NULL) {
        fprintf(stderr, "Failed to open file!\n");
        return 1;
    }

    byte* block = malloc(BLOCK_SIZE * sizeof(byte));
    unsigned long long matchedByteAmount = 0;
    size_t i = 0;
    while (i < MAX_BLOCKS) {
        i++;
        const size_t byteCount = fread(block, sizeof(byte), BLOCK_SIZE, file);
        if (byteCount == 0) {
            if (!feof(file)) {
                fprintf(stderr, "Failed to read file, an error occured!\n");
                return 1;
            }
            break;
        }
        matchedByteAmount += CountMatchingBytes(block, byteCount, COUNTED_BYTE);
    }
    if (i >= MAX_BLOCKS) {
        fprintf(stderr, "Did not read file, reached maximum size before EOF!\n");
        return 1;
    }

    fprintf(stderr, "Found number of bytes matching 0x%02x:\n", COUNTED_BYTE);
    printf("%llu", matchedByteAmount);
    free(block);
    fclose(file);
    return EXIT_SUCCESS;
}

char* GetFileName(const int argc, char* const argv[]) {
    char* fileName;
    if (argc > 1) {
        const size_t fileNameCount = strlen(argv[1]) + 1;  // +1 for \0
        fileName = malloc(fileNameCount * sizeof(char));
        strcpy(fileName, argv[1]);
    } else {
        const char defaultFileName[] = "dummy_file.bin";
        fileName = malloc(sizeof(defaultFileName));
        strcpy(fileName, defaultFileName);
    }
    return fileName;
}

unsigned long long CountMatchingBytes(byte* const block, const size_t byteCount, const byte byteValue) {
    unsigned long long count = 0;
    for (size_t i = 0; i < byteCount; i++) {
        if (block[i] == byteValue) {
            count++;
        }
    }
    return count;
}
