#include <stdio.h>
#include <stdlib.h>

#define FILE_SIZE ((1 << 10) * (1 << 10) * 128)  // 128 MiB

void PrintProgress(const size_t ticks);

int main(void) {
    FILE* dummyFile = fopen64("dummy_file.bin", "w");
    srand(12);
    for (size_t t = 0; t < 10; t++) {
        for (size_t i = 0; i < (FILE_SIZE / 10); i++) {
            const unsigned char byte = (unsigned char)(rand() & UCHAR_MAX);
            fwrite(&byte, sizeof(byte), 1, dummyFile);
        }
        PrintProgress(t);
    }
    fprintf(stderr, "\n");
    return 0;
}

void PrintProgress(const size_t ticks) {
    fprintf(stderr, "\r[");
    for (size_t i = 0; i < ticks; i++)
        fprintf(stderr, "#");
    for (size_t i = 0; i < (9 - ticks); i++)
        fprintf(stderr, " ");
    fprintf(stderr, "]");
}
