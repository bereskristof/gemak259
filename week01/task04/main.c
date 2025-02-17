/*
 *  4. Vektorok összeadása
 *  * Készítsünk programot két valós vektor összeadására!
 *  * Szervezzük át a programot úgy, hogy a függvény hívásakor ne látszódjon,
 *    hogy OpenCL-es implementációról van szó!
 *  * Szekvenciális programmal ellenőríztessük az eredmény helyességét!
 */

#include "main.h"
#define VEC_SIZE (1 << 9)
#define THREADS_COUNT VEC_SIZE
#define SOURCE_SIZE (1 << 10)
#define RESULT_SLICE 10

int main(void) {
    cl_int clResult;

    // Platforms
    cl_platform_id platformId;
    {
        const cl_uint platformMaxCount = 3;
        cl_uint platformCount;
        cl_platform_id platformIds[platformMaxCount];
        clResult = clGetPlatformIDs(platformMaxCount, platformIds, &platformCount);
        if (clResult != CL_SUCCESS)
            PanicAndQuit("Error: clGetPlatformIDs failed (Code: %d)\n", clResult);
        PrintClPlatforms(platformCount, platformIds);
        platformId = platformIds[0];
    }

    // Device
    cl_device_id deviceId;
    {
        const cl_uint deviceMaxCount = 3;
        cl_uint deviceCount;
        cl_device_id deviceIds[deviceMaxCount];
        clResult = clGetDeviceIDs(platformId, CL_DEVICE_TYPE_ALL, deviceMaxCount, deviceIds, &deviceCount);
        if (clResult != CL_SUCCESS)
            PanicAndQuit("Error: clGetDeviceIDs failed (Code: %d)\n", clResult);
        PrintClDevices(deviceCount, deviceIds);
        deviceId = deviceIds[0];
    }

    // Context
    cl_context context = clCreateContext(NULL, 1, &deviceId, NULL, NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clCreateContext failed (Code: %d)\n", clResult);

    // Program
    cl_program program;
    {
        const size_t programSourceMaxSize = SOURCE_SIZE;
        char programSourceText[programSourceMaxSize];
        char programSourcePath[] = "./vec-add.cl";
        enum UtilErr loadResult = LoadTextFile(programSourceText, programSourceMaxSize, programSourcePath);
        if (loadResult != UERR_NONE)
            PanicAndQuit("Error: LoadTextFile failed (Code: %d)\n", (int)loadResult);
        const char* programSourceStringArray[] = {&programSourceText[0]};
        program = clCreateProgramWithSource(context, 1, programSourceStringArray, NULL, &clResult);
        if (clResult != CL_SUCCESS)
            PanicAndQuit("Error: clCreateProgramWithSource failed (Code: %d)\n", clResult);
        clResult = clBuildProgram(program, 1, &deviceId, NULL, NULL, NULL);
        if (clResult != CL_SUCCESS)
            PanicAndQuit("Error: clBuildProgram failed (Code: %d)\n", clResult);
    }

    // Kernel
    cl_kernel kernel = clCreateKernel(program, "VectorAdd", &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clCreateKernel failed (Code: %d)\n", clResult);

    // Args -> Host
    int vecA[VEC_SIZE] = {};
    int vecB[VEC_SIZE] = {};
    int vecResult[VEC_SIZE];
    srand(17);                               // Same seed is used to keep separate runs the same
    for (size_t i = 0; i < VEC_SIZE; i++) {  // Randomly fills vectors with data
        vecA[i] = rand() % 100;
        vecB[i] = rand() % 100;
    }

    // Args -> Device
    cl_mem deviceVecA = clCreateBuffer(context, CL_MEM_READ_ONLY, sizeof(vecA), NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clCreateBuffer[0] failed (Code: %d)\n", clResult);
    cl_mem deviceVecB = clCreateBuffer(context, CL_MEM_READ_ONLY, sizeof(vecB), NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clCreateBuffer[1] failed (Code: %d)\n", clResult);
    cl_mem deviceVecResult = clCreateBuffer(context, CL_MEM_WRITE_ONLY, sizeof(vecResult), NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clCreateBuffer[2] failed (Code: %d)\n", clResult);

    clResult = clSetKernelArg(kernel, 0, sizeof(deviceVecA), (void*)&deviceVecA);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clSetKernelArg[0] failed (Code: %d)\n", clResult);
    clResult = clSetKernelArg(kernel, 1, sizeof(deviceVecB), (void*)&deviceVecB);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clSetKernelArg[1] failed (Code: %d)\n", clResult);
    clResult = clSetKernelArg(kernel, 2, sizeof(deviceVecResult), (void*)&deviceVecResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clSetKernelArg[2] failed (Code: %d)\n", clResult);
    const int threadCount = THREADS_COUNT;
    clResult = clSetKernelArg(kernel, 3, sizeof(threadCount), (void*)&threadCount);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clSetKernelArg[3] failed (Code: %d)\n", clResult);

    cl_command_queue commandQueue = clCreateCommandQueueWithProperties(context, deviceId, NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("Error: clCreateCommandQueue failed (Code: %d)\n", clResult);

    // Moving vectors from Host to Device
    clEnqueueWriteBuffer(commandQueue, deviceVecA, CL_FALSE, 0, sizeof(vecA), (void*)vecA, 0, NULL, NULL);
    clEnqueueWriteBuffer(commandQueue, deviceVecB, CL_FALSE, 0, sizeof(vecB), (void*)vecB, 0, NULL, NULL);
    clEnqueueWriteBuffer(commandQueue, deviceVecResult, CL_FALSE, 0, sizeof(vecResult), (void*)vecResult, 0, NULL,
                         NULL);

    // Setting up GPU execution
    const size_t totalSize = THREADS_COUNT;
    const size_t workSize = 256;

    // Calculate result vector & return it
    clEnqueueNDRangeKernel(commandQueue, kernel, 1, NULL, &totalSize, &workSize, 0, NULL, NULL);
    clEnqueueReadBuffer(commandQueue, deviceVecResult, CL_TRUE, 0, sizeof(vecResult), (void*)&vecResult, 0, NULL, NULL);

    // Prints results
    printf("First %d results:\n", RESULT_SLICE);
    printf(" vecA   vecB    vecRes\n");
    for (size_t i = 0; i < RESULT_SLICE; i++) {
        printf("   %2d +   %2d ->    %3d\n", vecA[i], vecB[i], vecResult[i]);
    }
    printf("Sequential test results: %s\n",
           TestVectorAdd(vecA, vecB, vecResult, sizeof(vecA) / sizeof(vecA[0])) ? "PASS" : "FAIL");

    // Release
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseContext(context);
    clReleaseDevice(deviceId);
    return 0;
}

// Lists every found CL platform to StdOut
void PrintClPlatforms(const size_t count, cl_platform_id ids[]) {
    printf("Found platforms:\n");
    for (size_t i = 0; i < count; i++) {
        char name[256];
        clGetPlatformInfo(ids[i], CL_PLATFORM_NAME, sizeof(name), name, NULL);
        printf(" * %s\n", name);
    }
}

// Lists every found CL device to StdOut
void PrintClDevices(const size_t count, cl_device_id ids[]) {
    printf("Found devices:\n");
    for (size_t i = 0; i < count; i++) {
        char name[256];
        clGetDeviceInfo(ids[i], CL_DEVICE_NAME, sizeof(name), name, NULL);
        printf(" * %s\n", name);
    }
}

// Prints the message formatted with code to StdErr, then exits
void PanicAndQuit(const char messageFormat[], const int code) {
    fprintf(stderr, messageFormat, code);
    exit(code);
}

// Checks if the sum of two vectors matches the provided result,
// return true if the vector is correct
// WARN: Mismatched vector sizes can cause overflow
bool TestVectorAdd(const int a[], const int b[], const int result[], const size_t vecSize) {
    for (size_t i = 0; i < vecSize; i++)
        if (result[i] != a[i] + b[i])
            return false;
    return true;
}
