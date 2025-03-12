#ifndef GENERATE_FILE_C
#define GENERATE_FILE_C

#include <stdio.h>
#include <stdlib.h>

#define FILE_SIZE ((1 << 10) * (1 << 10) * 128)  // 128 MiB

void PrintProgress(const size_t ticks);

#endif  // GENERATE_FILE_C
