#include "utils.h"

static void PrintClPlatforms(const size_t count, cl_platform_id ids[]);
static void PrintClDevices(const size_t count, cl_device_id ids[]);

struct GlobalUtilConf globalUtilConf = {
    .initClPrintLog = false,
    .loadClProgramMaxCharCount = 4096,
};

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
        PrintClErr("clGetPlatformIDs failed", clResult);
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
        PrintClErr("clGetDeviceIDs failed", clResult);
        return UERR_CL_GET_DEVICE_FAILED;
    }
    if (globalUtilConf.initClPrintLog)
        PrintClDevices(deviceCount, deviceIds);
    *deviceId = deviceIds[0];

    // Context
    *context = clCreateContext(NULL, 1, deviceId, NULL, NULL, &clResult);
    if (clResult != CL_SUCCESS) {
        PrintClErr("clCreateContext failed", clResult);
        return UERR_CL_CREATE_CONTEXT_FAILED;
    }

    // Command queue
    *queue = clCreateCommandQueueWithProperties(*context, *deviceId, NULL, &clResult);
    if (clResult != CL_SUCCESS) {
        PrintClErr("clCreateCommandQueueWithProperties failed", clResult);
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
        PrintErr("LoadTextFile failed %d", (int)loadResult);
        free(programSourceText);
        return UERR_FILE_IO_FAILED;
    }

    // Load text into program
    const char* programSourceStringArray[] = {&programSourceText[0]};
    *program = clCreateProgramWithSource(*context, 1, programSourceStringArray, NULL, &clResult);
    free(programSourceText);
    if (clResult != CL_SUCCESS) {
        PrintClErr("clCreateProgramWithSource failed", clResult);
        return UERR_CL_CREATE_PROGRAM_FAILED;
    }
    clResult = clBuildProgram(*program, 1, deviceId, (char*)"-w", NULL, NULL);
    if (clResult != CL_SUCCESS && clResult != CL_BUILD_PROGRAM_FAILURE) {
        PrintClErr("clBuildProgram failed", clResult);
        return UERR_CL_BUILD_PROGRAM_FAILED;
    }

    // Prints build log to StdErr if the build failed or warning are returned
    const bool buildFailed = clResult == CL_BUILD_PROGRAM_FAILURE;
    size_t logSize = 0;
    clResult = clGetProgramBuildInfo(*program, *deviceId, CL_PROGRAM_BUILD_LOG, 0, NULL, &logSize);
    if (clResult != CL_SUCCESS) {
        PrintClErr("Can't query build log, fatal error! [0]", clResult);
        exit(-1);
    }
    if (logSize > 2 || buildFailed) {
        if (buildFailed)
            fprintf(stderr, "\033[30;101m OpenCL build failure \033[0m\n");
        else
            fprintf(stderr, "\033[30;103m OpenCL build warning \033[0m\n");

        char* logMessage = malloc((logSize + 1) * sizeof(char));
        clResult = clGetProgramBuildInfo(*program, *deviceId, CL_PROGRAM_BUILD_LOG, logSize + 1, logMessage, &logSize);
        if (clResult != CL_SUCCESS) {
            PrintClErr("Can't query build log, fatal error! [1]", clResult);
            exit(-1);
        }
        logMessage[logSize] = '\0';
        fprintf(stderr, logMessage);
    }

    return buildFailed ? UERR_CL_BUILD_PROGRAM_FAILED : UERR_NONE;
}

// Sets up an OpenCl containers platform, device, context, and queue with default values
// NOTE: Freeing resources must be done maually
enum UtilErr InitClContainer(struct ClContainer const* container) {
    InitCl(&container->context, &container->device, &container->context, &container->queue);
}

// Loads .cl file into an OpenCL containers program
enum UtilErr LoadClContainerProgram(struct ClContainer const* container, const char filePath[]) {
    LoadClProgram(&container->program, filePath, &container->device, &container->context);
}

// Frees up resources used by OpenCL container
void FreeClContainer(struct ClContainer const* container) {
    clReleaseKernel(container->kernel);  // TODO: Make this check errors?
    clReleaseProgram(container->program);
    clReleaseCommandQueue(container->queue);
    clReleaseContext(container->context);
    clReleaseDevice(container->device);
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

// Prints formatted message to StdErr
void PrintErr(const char errorMsg[], ...) {
    fprintf(stderr, "\033[30;101m Error \033[0m ");
    va_list args;
    va_start(args, errorMsg);
    vfprintf(stderr, errorMsg, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// Prints formatted message to StdErr, and writes CL error value as a string to StdErr
void PrintClErr(const char errorMsg[], const cl_int errorCode) {
    PrintErr(errorMsg);
    fprintf(stderr, "(CL %d) ", errorCode);
    switch (errorCode) {
        case CL_SUCCESS:
            fprintf(stderr, "Success! ");
            break;
        case CL_DEVICE_NOT_FOUND:
            fprintf(stderr, "Device not found! ");
            break;
        case CL_DEVICE_NOT_AVAILABLE:
            fprintf(stderr, "Device not available! ");
            break;
        case CL_COMPILER_NOT_AVAILABLE:
            fprintf(stderr, "Compiler not available! ");
            break;
        case CL_MEM_OBJECT_ALLOCATION_FAILURE:
            fprintf(stderr, "Mem object allocation failure! ");
            break;
        case CL_OUT_OF_RESOURCES:
            fprintf(stderr, "Out of resources! ");
            break;
        case CL_OUT_OF_HOST_MEMORY:
            fprintf(stderr, "Out of host memory! ");
            break;
        case CL_PROFILING_INFO_NOT_AVAILABLE:
            fprintf(stderr, "Profiling info not available! ");
            break;
        case CL_MEM_COPY_OVERLAP:
            fprintf(stderr, "Mem copy overlap! ");
            break;
        case CL_IMAGE_FORMAT_MISMATCH:
            fprintf(stderr, "Image format mismatch! ");
            break;
        case CL_IMAGE_FORMAT_NOT_SUPPORTED:
            fprintf(stderr, "Image format not supported! ");
            break;
        case CL_BUILD_PROGRAM_FAILURE:
            fprintf(stderr, "Build program failure! ");
            break;
        case CL_MAP_FAILURE:
            fprintf(stderr, "Map failure! ");
            break;
        case CL_MISALIGNED_SUB_BUFFER_OFFSET:
            fprintf(stderr, "Misaligned sub buffer offset! ");
            break;
        case CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST:
            fprintf(stderr, "Exec status error for events in wait list! ");
            break;
        case CL_COMPILE_PROGRAM_FAILURE:
            fprintf(stderr, "Compile program failure! ");
            break;
        case CL_LINKER_NOT_AVAILABLE:
            fprintf(stderr, "Linker not available! ");
            break;
        case CL_LINK_PROGRAM_FAILURE:
            fprintf(stderr, "Link program failure! ");
            break;
        case CL_DEVICE_PARTITION_FAILED:
            fprintf(stderr, "Device partition failed! ");
            break;
        case CL_KERNEL_ARG_INFO_NOT_AVAILABLE:
            fprintf(stderr, "Kernel arg info not available! ");
            break;
        case CL_INVALID_VALUE:
            fprintf(stderr, "Invalid value! ");
            break;
        case CL_INVALID_DEVICE_TYPE:
            fprintf(stderr, "Invalid device type! ");
            break;
        case CL_INVALID_PLATFORM:
            fprintf(stderr, "Invalid platform! ");
            break;
        case CL_INVALID_DEVICE:
            fprintf(stderr, "Invalid device! ");
            break;
        case CL_INVALID_CONTEXT:
            fprintf(stderr, "Invalid context! ");
            break;
        case CL_INVALID_QUEUE_PROPERTIES:
            fprintf(stderr, "Invalid queue properties! ");
            break;
        case CL_INVALID_COMMAND_QUEUE:
            fprintf(stderr, "Invalid command queue! ");
            break;
        case CL_INVALID_HOST_PTR:
            fprintf(stderr, "Invalid host ptr! ");
            break;
        case CL_INVALID_MEM_OBJECT:
            fprintf(stderr, "Invalid mem object! ");
            break;
        case CL_INVALID_IMAGE_FORMAT_DESCRIPTOR:
            fprintf(stderr, "Invalid image format descriptor! ");
            break;
        case CL_INVALID_IMAGE_SIZE:
            fprintf(stderr, "Invalid image size! ");
            break;
        case CL_INVALID_SAMPLER:
            fprintf(stderr, "Invalid sampler! ");
            break;
        case CL_INVALID_BINARY:
            fprintf(stderr, "Invalid binary! ");
            break;
        case CL_INVALID_BUILD_OPTIONS:
            fprintf(stderr, "Invalid build options! ");
            break;
        case CL_INVALID_PROGRAM:
            fprintf(stderr, "Invalid program! ");
            break;
        case CL_INVALID_PROGRAM_EXECUTABLE:
            fprintf(stderr, "Invalid program executable! ");
            break;
        case CL_INVALID_KERNEL_NAME:
            fprintf(stderr, "Invalid kernel name! ");
            break;
        case CL_INVALID_KERNEL_DEFINITION:
            fprintf(stderr, "Invalid kernel definition! ");
            break;
        case CL_INVALID_KERNEL:
            fprintf(stderr, "Invalid kernel! ");
            break;
        case CL_INVALID_ARG_INDEX:
            fprintf(stderr, "Invalid arg index! ");
            break;
        case CL_INVALID_ARG_VALUE:
            fprintf(stderr, "Invalid arg value! ");
            break;
        case CL_INVALID_ARG_SIZE:
            fprintf(stderr, "Invalid arg size! ");
            break;
        case CL_INVALID_KERNEL_ARGS:
            fprintf(stderr, "Invalid kernel args! ");
            break;
        case CL_INVALID_WORK_DIMENSION:
            fprintf(stderr, "Invalid work dimension! ");
            break;
        case CL_INVALID_WORK_GROUP_SIZE:
            fprintf(stderr, "Invalid work group size! ");
            break;
        case CL_INVALID_WORK_ITEM_SIZE:
            fprintf(stderr, "Invalid work item size! ");
            break;
        case CL_INVALID_GLOBAL_OFFSET:
            fprintf(stderr, "Invalid global offset! ");
            break;
        case CL_INVALID_EVENT_WAIT_LIST:
            fprintf(stderr, "Invalid event wait list! ");
            break;
        case CL_INVALID_EVENT:
            fprintf(stderr, "Invalid event! ");
            break;
        case CL_INVALID_OPERATION:
            fprintf(stderr, "Invalid operation! ");
            break;
        case CL_INVALID_GL_OBJECT:
            fprintf(stderr, "Invalid gl object! ");
            break;
        case CL_INVALID_BUFFER_SIZE:
            fprintf(stderr, "Invalid buffer size! ");
            break;
        case CL_INVALID_MIP_LEVEL:
            fprintf(stderr, "Invalid mip level! ");
            break;
        case CL_INVALID_GLOBAL_WORK_SIZE:
            fprintf(stderr, "Invalid global work size! ");
            break;
        case CL_INVALID_PROPERTY:
            fprintf(stderr, "Invalid property! ");
            break;
        case CL_INVALID_IMAGE_DESCRIPTOR:
            fprintf(stderr, "Invalid image descriptor! ");
            break;
        case CL_INVALID_COMPILER_OPTIONS:
            fprintf(stderr, "Invalid compiler options! ");
            break;
        case CL_INVALID_LINKER_OPTIONS:
            fprintf(stderr, "Invalid linker options! ");
            break;
        case CL_INVALID_DEVICE_PARTITION_COUNT:
            fprintf(stderr, "Invalid device partition count! ");
            break;
        case CL_INVALID_PIPE_SIZE:
            fprintf(stderr, "Invalid pipe size! ");
            break;
        case CL_INVALID_DEVICE_QUEUE:
            fprintf(stderr, "Invalid device queue! ");
            break;
        case CL_INVALID_SPEC_ID:
            fprintf(stderr, "Invalid spec id! ");
            break;
        case CL_MAX_SIZE_RESTRICTION_EXCEEDED:
            fprintf(stderr, "Max size restriction exceeded! ");
            break;
        default:
            fprintf(stderr, "Unknown! ");
            break;
    }
}
