#include "main.h"

// Finds a vectors sliding average
void SubroutineAverageVectors(struct ClContainer* cl, float vec[], const size_t vecSize) {
    enum UtilErr err;
    cl_int clErr;
    float* vecRes = malloc(ARRAY_SIZE * sizeof(float));

    // Kernel
    err = LoadClContainerKernel(cl, "./sliding_avg_vector.cl", "VectorSAvg");
    if (err != UERR_NONE) {
        goto freeingReturn;
    }

    // Memory
    const size_t vecByteSize = vecSize * sizeof(vec[0]);
    cl_mem clVec = clCreateBuffer(cl->context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, vecByteSize, vec, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not load 1st vector", clErr);
        goto freeingReturn;
    }
    cl_mem clRes = clCreateBuffer(cl->context, CL_MEM_WRITE_ONLY, vecByteSize, NULL, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not load 2nd vector", clErr);
        goto freeingReturn;
    }

    // Args
    clErr = clSetKernelArg(cl->kernel, 0, sizeof(clVec), &clVec);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 1st arg", clErr);
        goto freeingReturn;
    }
    clErr = clSetKernelArg(cl->kernel, 1, sizeof(clRes), &clRes);
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
    int safeThreadCount = (int)256;
    clErr = clSetKernelArg(cl->kernel, 3, sizeof(safeThreadCount), &safeThreadCount);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 4th arg", clErr);
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
    clErr = clEnqueueReadBuffer(cl->queue, clRes, CL_TRUE, 0, vecByteSize, (void*)vecRes, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Failed to read from device", clErr);
        goto freeingReturn;
    }

    // Printing result
    fprintf(stdout, "Calculated average vector: ");
    PrintArrayPreview(vecRes, ARRAY_SIZE, stdout);

    // CPU-side verification
    const int range = 16;
    for (int i = 0; i < ARRAY_SIZE; i++) {
        float total = 0.0f;
        float count = 0.0f;
        for (int r = -(range - 1); r < range; r++) {
            if (r < 0 || r >= ARRAY_SIZE)
                continue;
            total += vec[i + r];
            count += 1.0f;
        }
        const float avg = total / count;
        if (fabs(vecRes[i] - avg) > 0.0001) {
            fprintf(stdout, "\033[91mArrays do not match! (@%d %f != %f)\033[0m\n", i, avg, vecRes[i]);
            goto freeingReturn;
        }
    }
    fprintf(stdout, "\033[92mArrays match!\033[0m\n");

// Freeing
freeingReturn:
    free(vecRes);
}
