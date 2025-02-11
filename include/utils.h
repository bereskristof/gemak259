#ifndef UTILS_C
#define UTILS_C

#ifndef CL_TARGET_OPENCL_VERSION
#define CL_TARGET_OPENCL_VERSION 300
#endif

#include <CL/cl.h>
#include <stdio.h>
#include <stdlib.h>

enum UtilErr {
    UERR_NONE = 0,
    UERR_FILE_IO_FAILED,
    UERR_BUFFER_OVERFLOW,
};

enum UtilErr LoadTextFile(char* const textBuffer, const size_t textBufferSize, const char filePath[]);

#endif  // UTILS_C
