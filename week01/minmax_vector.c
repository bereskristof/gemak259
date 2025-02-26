#include "main.h"

// Finds a vectors min and max
void SubroutineMinMaxVectors(struct ClContainer* cl, float vec[], const size_t vecSize, const bool isMaxOverMin) {
    enum UtilErr err;
    cl_int clErr;

    // Kernel
    err = LoadClContainerKernel(cl, "./minmax_vector.cl", isMaxOverMin ? "VectorMax" : "VectorMin");
    if (err != UERR_NONE) {
        return;
    }

    // Memory
    const size_t vecByteSize = vecSize * sizeof(vec[0]);
    cl_mem clVec = clCreateBuffer(cl->context, CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR, vecByteSize, vec, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not load 1st vector", clErr);
        return;
    }

    // Args
    clErr = clSetKernelArg(cl->kernel, 0, sizeof(clVec), &clVec);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 1st arg", clErr);
        return;
    }
    int safeVecSize = (int)vecSize;
    clErr = clSetKernelArg(cl->kernel, 1, sizeof(safeVecSize), &safeVecSize);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 2nd arg", clErr);
        return;
    }
    int safeThreadCount = (int)256;
    clErr = clSetKernelArg(cl->kernel, 2, sizeof(safeThreadCount), &safeThreadCount);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 3rd arg", clErr);
        return;
    }

    // Calculation & data return
    const size_t totalSize = 256;
    const size_t workSize = 256;
    clErr = clEnqueueNDRangeKernel(cl->queue, cl->kernel, 1, NULL, &totalSize, &workSize, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Failed to execute kernel", clErr);
        return;
    }
    float extremum = 0.0f;
    clErr = clEnqueueReadBuffer(cl->queue, clVec, CL_TRUE, 0, sizeof(float), (void*)&extremum, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Failed to read from device", clErr);
        return;
    }

    // Printing result
    fprintf(stdout, "Found %s: %f\n", (isMaxOverMin ? "maximum" : "minimum"), extremum);

    // CPU-side verification
    float min = 100000.0f;
    float max = -min;
    for (size_t i = 0; i < vecSize; i++) {
        if (max < vec[i]) {
            max = vec[i];
        }
        if (min > vec[i]) {
            min = vec[i];
        }
    }
    if (extremum == (isMaxOverMin ? max : min)) {
        fprintf(stdout, "\033[92mExtremums match!\033[0m\n");
    } else {
        fprintf(stdout, "\033[91mExtremums don't match!\033[0m\n");
    }
}
