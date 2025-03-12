#ifndef MAIN_C
#define MAIN_C

#include <stdio.h>
#include <stdlib.h>
#include <utils.h>

#ifndef BLOCK_SIZE
#define BLOCK_SIZE ((1 << 10) * 16) /* 16 KiB */
#endif

#ifndef COUNTED_BYTE
#define COUNTED_BYTE 0x00
#endif

#ifndef MAX_BLOCKS
#define MAX_BLOCKS ((((1 << 30) * 2ULL) + BLOCK_SIZE - 1) / BLOCK_SIZE) /* Enough blocks for 2 GiB */
#endif

typedef unsigned char byte;

char* GetFileName(const int argc, char* const argv[]);
unsigned long long CountMatchingBytes(byte* const block, const size_t byteCount, const byte byteValue);

#endif  // MAIN_C
