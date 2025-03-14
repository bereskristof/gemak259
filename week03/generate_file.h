#ifndef GENERATE_FILE_C
#define GENERATE_FILE_C

#include <stdio.h>
#include <stdlib.h>

#ifndef FILE_SIZE
#define FILE_SIZE ((1 << 20) * 128) /* 128 MiB */
#endif

void PrintProgress(const size_t ticks);
bool IfFileExists(void);

#endif  // GENERATE_FILE_C
