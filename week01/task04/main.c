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
    // Args -> Host
    int vecA[VEC_SIZE] = {};
    int vecB[VEC_SIZE] = {};
    int vecResult[VEC_SIZE] = {};
    srand(17);                               // Same seed is used to keep separate runs the same
    for (size_t i = 0; i < VEC_SIZE; i++) {  // Randomly fills vectors with data
        vecA[i] = rand() % 100;
        vecB[i] = rand() % 100;
    }

    globalUtilConf.initClPrintLog = true;
    MatrixMultCl(vecA, vecB, vecResult, VEC_SIZE);

    // Prints results
    printf("First %d results:\n", RESULT_SLICE);
    printf(" vecA   vecB    vecRes\n");
    for (size_t i = 0; i < RESULT_SLICE; i++) {
        printf("   %2d +   %2d ->    %3d\n", vecA[i], vecB[i], vecResult[i]);
    }
    printf("Sequential test results: %s\n",
           TestVectorAdd(vecA, vecB, vecResult, sizeof(vecA) / sizeof(vecA[0])) ? "PASS" : "FAIL");
    return 0;
}

void MatrixMultCl(const int vecA[], const int vecB[], int vecResult[], const size_t vecSize) {
    const size_t vecByteSize = sizeof(vecA[0]) * vecSize;
    enum UtilErr utilResult;
    cl_int clResult;

    // Setup
    cl_platform_id platformId;
    cl_device_id deviceId;
    cl_context context;
    cl_command_queue commandQueue;
    utilResult = InitCl(&platformId, &deviceId, &context, &commandQueue);
    if (utilResult != UERR_NONE)
        PanicAndQuit("InitCl failed (Code: %d)", (int)utilResult);

    // Program
    cl_program program;
    utilResult = LoadClProgram(&program, "./vec-add.cl", &deviceId, &context);
    if (utilResult != UERR_NONE)
        PanicAndQuit("LoadClProgram failed (Code: %d)", (int)utilResult);

    // Kernel
    cl_kernel kernel = clCreateKernel(program, "VectorAdd", &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clCreateKernel failed (Code: %d)", clResult);

    // Args -> Device
    cl_mem deviceVecA = clCreateBuffer(context, CL_MEM_READ_ONLY, vecByteSize, NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clCreateBuffer[0] failed (Code: %d)", clResult);
    cl_mem deviceVecB = clCreateBuffer(context, CL_MEM_READ_ONLY, vecByteSize, NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clCreateBuffer[1] failed (Code: %d)", clResult);
    cl_mem deviceVecResult = clCreateBuffer(context, CL_MEM_WRITE_ONLY, vecByteSize, NULL, &clResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clCreateBuffer[2] failed (Code: %d)", clResult);

    clResult = clSetKernelArg(kernel, 0, sizeof(deviceVecA), (void*)&deviceVecA);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clSetKernelArg[0] failed (Code: %d)", clResult);
    clResult = clSetKernelArg(kernel, 1, sizeof(deviceVecB), (void*)&deviceVecB);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clSetKernelArg[1] failed (Code: %d)", clResult);
    clResult = clSetKernelArg(kernel, 2, sizeof(deviceVecResult), (void*)&deviceVecResult);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clSetKernelArg[2] failed (Code: %d)", clResult);
    const int threadCount = THREADS_COUNT;
    clResult = clSetKernelArg(kernel, 3, sizeof(threadCount), (void*)&threadCount);
    if (clResult != CL_SUCCESS)
        PanicAndQuit("clSetKernelArg[3] failed (Code: %d)", clResult);

    // Moving vectors from Host to Device
    clEnqueueWriteBuffer(commandQueue, deviceVecA, CL_FALSE, 0, vecByteSize, (void*)vecA, 0, NULL, NULL);
    clEnqueueWriteBuffer(commandQueue, deviceVecB, CL_FALSE, 0, vecByteSize, (void*)vecB, 0, NULL, NULL);
    clEnqueueWriteBuffer(commandQueue, deviceVecResult, CL_FALSE, 0, vecByteSize, (void*)vecResult, 0, NULL, NULL);

    // Setting up GPU execution
    const size_t totalSize = THREADS_COUNT;
    const size_t workSize = 256;

    // Calculate result vector & return it
    clEnqueueNDRangeKernel(commandQueue, kernel, 1, NULL, &totalSize, &workSize, 0, NULL, NULL);
    clEnqueueReadBuffer(commandQueue, deviceVecResult, CL_TRUE, 0, vecByteSize, (void*)vecResult, 0, NULL, NULL);

    // Release
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseContext(context);
    clReleaseDevice(deviceId);
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

void PanicAndQuit(const char messageFormat[], const int code) {
    PrintErr(messageFormat, code);
    exit(code);
}
