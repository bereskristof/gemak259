#include "main.h"

// Adds two arrays togerther, and prints the result to StdOut
void SubroutineAddVectors(struct ClContainer* cl, float vec1[], float vec2[], const size_t vecSize) {
    enum UtilErr err;
    cl_int clErr;
    float* vecSum = malloc(vecSize * sizeof(float));

    // Kernel
    err = LoadClContainerKernel(cl, "./add_vector.cl", "VectorAdd");
    if (err != UERR_NONE) {
        goto freeingReturn;
    }

    // Memory
    const size_t vecByteSize = vecSize * sizeof(vec1[0]);
    cl_mem clVec1 = clCreateBuffer(cl->context, CL_MEM_READ_WRITE, vecByteSize, NULL, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not load 1st vector", clErr);
        goto freeingReturn;
    }
    cl_mem clVec2 = clCreateBuffer(cl->context, CL_MEM_READ_ONLY, vecByteSize, NULL, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not load 2nd vector", clErr);
        goto freeingReturn;
    }

    // Args
    clErr = clSetKernelArg(cl->kernel, 0, sizeof(clVec1), &clVec1);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 1st arg", clErr);
        goto freeingReturn;
    }
    clErr = clSetKernelArg(cl->kernel, 1, sizeof(clVec2), &clVec2);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 2nd arg", clErr);
        goto freeingReturn;
    }
    int safeVecSize = (int)vecSize;
    clErr = clSetKernelArg(cl->kernel, 2, sizeof(safeVecSize), &safeVecSize);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 3rd arg", clErr);
        goto freeingReturn;
    }

    // Moving data to device
    clErr = clEnqueueWriteBuffer(cl->queue, clVec1, CL_FALSE, 0, vecByteSize, (void*)vec1, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not copy 1st arg", clErr);
        goto freeingReturn;
    }
    clErr = clEnqueueWriteBuffer(cl->queue, clVec2, CL_FALSE, 0, vecByteSize, (void*)vec2, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not copy 2nd arg", clErr);
        goto freeingReturn;
    }

    // Calculation & data return
    const size_t totalSize = THREADS_COUNT;
    const size_t workSize = 256;
    clErr = clEnqueueNDRangeKernel(cl->queue, cl->kernel, 1, NULL, &totalSize, &workSize, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Failed to execute kernel", clErr);
        goto freeingReturn;
    }
    clErr = clEnqueueReadBuffer(cl->queue, clVec1, CL_TRUE, 0, vecByteSize, (void*)vecSum, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Failed to read from device", clErr);
        goto freeingReturn;
    }

    // Printing result
    fprintf(stdout, "Array 1: ");
    PrintArrayPreview(vec1, vecSize, stdout);
    fprintf(stdout, "Array 2: ");
    PrintArrayPreview(vec2, vecSize, stdout);
    fprintf(stdout, "Array +: ");
    PrintArrayPreview(vecSum, vecSize, stdout);

    // CPU-side verification
    for (size_t i = 0; i < vecSize; i++) {
        if (fabs((vec1[i] + vec2[i]) - vecSum[i]) > 0.00001) {
            fprintf(stdout, "\033[91mArrays do not match! (@%llu %f + %f != %f)\033[0m\n", i, vec1[i], vec2[i],
                    vecSum[i]);
            goto freeingReturn;
        }
    }
    fprintf(stdout, "\033[92mArrays match!\033[0m\n");

// Freeing
freeingReturn:
    free(vecSum);
}
