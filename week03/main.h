#ifndef MAIN_C
#define MAIN_C

#include <stdio.h>
#include <stdlib.h>
#include <utils.h>

#ifndef BLOCK_SIZE
#define BLOCK_SIZE ((1 << 10) * 256ULL) /* 256 KiB */
#endif

#ifndef COUNTED_BYTE
#define COUNTED_BYTE 0x00
#endif

#ifndef MAX_BLOCKS
#define MAX_BLOCKS ((((1 << 30) * 2ULL) + BLOCK_SIZE - 1) / BLOCK_SIZE) /* Enough blocks for 2 GiB */
#endif

// #define USE_HOST

#define SUCCESS 0
#define READ_ERROR -1
#define MAX_SIZE_ERROR -2
#define FILE_NULL_ERROR -3
#define CL_ANY_ERROR -4

typedef unsigned char byte;
typedef unsigned long long ulong;
typedef struct ClContainer* cl_ptr;

char* GetFileNameAlloc(const int argc, char* const argv[]);
ulong CountBlockBytes_Host(byte* const block, const size_t byteCount, const byte byteValue);
ulong CountBytes_Host(int* error, FILE* const file);
ulong CountBytes_Device(int* error, FILE* const file);
ulong IterateBlocks_Device(int* error, struct ClContainer* const cl, FILE* const file);
int EnqueueCountBlockBytes_Device(cl_event* e, ulong* n, cl_ptr const cl, const byte* block, const size_t count);
// void CL_CALLBACK CallbackCountBlockBytes_Device(cl_event event, cl_int status, void* userData);

#endif  // MAIN_C
