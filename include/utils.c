#include "utils.h"

static void PrintClPlatforms(const size_t count, cl_platform_id ids[]);
static void PrintClDevices(const size_t count, cl_device_id ids[]);

struct GlobalUtilConf globalUtilConf = (struct GlobalUtilConf){
    .initClPrintLog = false,
    .loadClProgramMaxCharCount = 4096,
};

// Prints formatted message to StdErr
void PrintErr(const char errorMsg[], ...) {
    fprintf(stderr, "\033[30;101m Error \033[0m ");
    va_list args;
    va_start(args, errorMsg);
    vfprintf(stderr, errorMsg, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// Loads the contents of the text file at `filePath` into `textBuffer`.
// Known issues: Failes if the target file is empty
enum UtilErr LoadTextFile(char* const textBuffer, const size_t textBufferSize, const char filePath[]) {
    FILE* const file = fopen(filePath, "r");
    if (file == NULL)
        return UERR_FILE_IO_FAILED;
    const size_t readChars = fread(textBuffer, sizeof(char), textBufferSize, file);
    const int lastCharIndex = ((textBufferSize - 1) > readChars) ? readChars : (textBufferSize - 1);
    int returnValue = UERR_NONE;
    if (textBuffer[lastCharIndex] != '\0')
        returnValue = UERR_BUFFER_OVERFLOW;
    fclose(file);
    return returnValue;
}

// Sets up OpenCl platform, device, context, and queue with default values
// NOTE: Freeing resources must be done maually
enum UtilErr InitCl(cl_platform_id* platformId, cl_device_id* deviceId, cl_context* context, cl_command_queue* queue) {
    cl_int clResult;

    // Platforms
    const cl_uint platformMaxCount = 3;
    cl_uint platformCount;
    cl_platform_id platformIds[platformMaxCount];
    clResult = clGetPlatformIDs(platformMaxCount, platformIds, &platformCount);
    if (clResult != CL_SUCCESS) {
        PrintErr("clGetPlatformIDs failed (Code: %d)", clResult);
        return UERR_CL_GET_PLATFORM_FAILED;
    }

    if (globalUtilConf.initClPrintLog)
        PrintClPlatforms(platformCount, platformIds);
    *platformId = platformIds[0];

    // Device
    const cl_uint deviceMaxCount = 3;
    cl_uint deviceCount;
    cl_device_id deviceIds[deviceMaxCount];
    clResult = clGetDeviceIDs(*platformId, CL_DEVICE_TYPE_ALL, deviceMaxCount, deviceIds, &deviceCount);
    if (clResult != CL_SUCCESS) {
        PrintErr("clGetDeviceIDs failed (Code: %d)", clResult);
        return UERR_CL_GET_DEVICE_FAILED;
    }
    if (globalUtilConf.initClPrintLog)
        PrintClDevices(deviceCount, deviceIds);
    *deviceId = deviceIds[0];

    // Context
    *context = clCreateContext(NULL, 1, deviceId, NULL, NULL, &clResult);
    if (clResult != CL_SUCCESS) {
        PrintErr("clCreateContext failed (Code: %d)", clResult);
        return UERR_CL_CREATE_CONTEXT_FAILED;
    }

    // Command queue
    *queue = clCreateCommandQueueWithProperties(*context, *deviceId, NULL, &clResult);
    if (clResult != CL_SUCCESS) {
        PrintErr("clCreateCommandQueueWithProperties failed (Code: %d)", clResult);
        return UERR_CL_CREATE_QUEUE_FAILED;
    }
    return UERR_NONE;
}

// Loads .cl file into an OpenCL program
enum UtilErr LoadClProgram(cl_program* program, const char fPath[], const cl_device_id* id, const cl_context* context) {
    cl_int clResult;
    const cl_device_id* deviceId = id;
    const size_t maxSize = globalUtilConf.loadClProgramMaxCharCount;

    // Load text file
    char* programSourceText = calloc(maxSize, sizeof(char));
    enum UtilErr loadResult = LoadTextFile(programSourceText, maxSize, fPath);
    if (loadResult != UERR_NONE) {
        PrintErr("LoadTextFile failed (Code: %d)", (int)loadResult);
        free(programSourceText);
        return UERR_FILE_IO_FAILED;
    }

    // Load text into program
    const char* programSourceStringArray[] = {&programSourceText[0]};
    *program = clCreateProgramWithSource(*context, 1, programSourceStringArray, NULL, &clResult);
    free(programSourceText);
    if (clResult != CL_SUCCESS) {
        PrintErr("clCreateProgramWithSource failed (Code: %d)", clResult);
        return UERR_CL_CREATE_PROGRAM_FAILED;
    }
    clResult = clBuildProgram(*program, 1, deviceId, NULL, NULL, NULL);
    if (clResult != CL_SUCCESS) {
        if (clResult != CL_BUILD_PROGRAM_FAILURE) {
            PrintErr("clBuildProgram failed (Code: %d)", clResult);
            return UERR_CL_BUILD_PROGRAM_FAILED;
        }
        // Prints build log to StdErr if the build failed
        fprintf(stderr, "\033[30;101m OpenCL build failure \033[0m\n");
        size_t logSize = 0;
        clResult = clGetProgramBuildInfo(*program, *deviceId, CL_PROGRAM_BUILD_LOG, 0, NULL, &logSize);
        if (clResult != CL_SUCCESS) {
            PrintErr("Can't query build error, terminating! (Code: %d)", clResult);
            exit(-1);
        }
        char* logMessage = malloc((logSize + 1) * sizeof(char));
        clResult = clGetProgramBuildInfo(*program, *deviceId, CL_PROGRAM_BUILD_LOG, logSize + 1, logMessage, &logSize);
        if (clResult != CL_SUCCESS) {
            PrintErr("Can't query build error, terminating! [1] (Code: %d)", clResult);
            exit(-1);
        }
        logMessage[logSize] = '\0';
        fprintf(stderr, "OpenCL build log:\n");
        fprintf(stderr, logMessage);
        free(logMessage);
        return UERR_CL_BUILD_PROGRAM_FAILED;
    }
    return UERR_NONE;
}

// Lists every found CL platform to StdOut
static void PrintClPlatforms(const size_t count, cl_platform_id ids[]) {
    printf("Found platforms:\n");
    for (size_t i = 0; i < count; i++) {
        char name[256];
        clGetPlatformInfo(ids[i], CL_PLATFORM_NAME, sizeof(name), name, NULL);
        printf(" * %s\n", name);
    }
}

// Lists every found CL device to StdOut
static void PrintClDevices(const size_t count, cl_device_id ids[]) {
    printf("Found devices:\n");
    for (size_t i = 0; i < count; i++) {
        char name[256];
        clGetDeviceInfo(ids[i], CL_DEVICE_NAME, sizeof(name), name, NULL);
        printf(" * %s\n", name);
    }
}
