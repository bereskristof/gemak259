#ifndef UTILS_C
#define UTILS_C

#ifndef CL_TARGET_OPENCL_VERSION
#define CL_TARGET_OPENCL_VERSION 300
#endif

#include <CL/cl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

// Global variables to configure util behaviour
extern struct GlobalUtilConf {
    bool initClPrintLog;               // Prints device and platform data to the console
    bool initClProfiling;              // Enables profiling for command queue
    size_t loadClProgramMaxCharCount;  // Maximum size of .cl file
} globalUtilConf;

struct ClContainer {
    cl_platform_id platform;
    cl_device_id device;
    cl_context context;
    cl_command_queue queue;
    cl_program program;
    cl_kernel kernel;
};

enum UtilErr {
    UERR_NONE = 0,
    UERR_FILE_IO_FAILED,
    UERR_BUFFER_OVERFLOW,
    UERR_CL_GET_PLATFORM_FAILED,
    UERR_CL_GET_DEVICE_FAILED,
    UERR_CL_CREATE_CONTEXT_FAILED,
    UERR_CL_CREATE_QUEUE_FAILED,
    UERR_CL_CREATE_PROGRAM_FAILED,
    UERR_CL_BUILD_PROGRAM_FAILED,
};

// OpenCL Wrappers
enum UtilErr LoadTextFile(char* const textBuffer, const size_t textBufferSize, const char filePath[]);
enum UtilErr InitCl(cl_platform_id* platformId, cl_device_id* deviceId, cl_context* context, cl_command_queue* queue);
enum UtilErr LoadClProgram(cl_program* program, const char fPath[], const cl_device_id* id, const cl_context* context);
enum UtilErr InitClContainer(struct ClContainer* container);
enum UtilErr LoadClContainerProgram(struct ClContainer* container, const char filePath[]);
enum UtilErr LoadClContainerKernel(struct ClContainer* cl, const char filePath[], const char functionName[]);
void FreeClContainer(struct ClContainer const* container);

// Error handling
void PrintErr(const char errorMsg[], ...);
void PrintClErr(const char errorMsg[], const cl_int errorCode);

#endif  // UTILS_C
