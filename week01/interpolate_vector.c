#include "main.h"

// Fills all NAN values in an array with the average of it's neighbours
void SubroutineInterpolateVectors(struct ClContainer* cl, float vec1[], const size_t vecSize) {
    enum UtilErr err;
    cl_int clErr;
    float* vecHoled = malloc(vecSize * sizeof(float));
    float* vecFilled = malloc(vecSize * sizeof(float));
    memcpy(vecHoled, vec1, vecSize * sizeof(vec1[0]));
    HoleArrayRandom(vecHoled, vecSize, 132);

    // Kernel
    err = LoadClContainerKernel(cl, "./interpolate_vector.cl", "VectorFill");
    if (err != UERR_NONE) {
        goto freeingReturn;
    }

    // Memory
    const size_t vecByteSize = vecSize * sizeof(vec1[0]);
    cl_mem clVecH = clCreateBuffer(cl->context, CL_MEM_READ_WRITE, vecByteSize, NULL, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not load 1st vector", clErr);
        goto freeingReturn;
    }

    // Args
    clErr = clSetKernelArg(cl->kernel, 0, sizeof(clVecH), &clVecH);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 1st arg", clErr);
        goto freeingReturn;
    }
    int safeVecSize = (int)vecSize;
    clErr = clSetKernelArg(cl->kernel, 1, sizeof(safeVecSize), &safeVecSize);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 2nd arg", clErr);
        goto freeingReturn;
    }

    // Moving data to device
    clErr = clEnqueueWriteBuffer(cl->queue, clVecH, CL_FALSE, 0, vecByteSize, (void*)vecHoled, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not copy 1st arg", clErr);
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
    clErr = clEnqueueReadBuffer(cl->queue, clVecH, CL_TRUE, 0, vecByteSize, (void*)vecFilled, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Failed to read from device", clErr);
        goto freeingReturn;
    }

    // Printing result
    fprintf(stdout, "Array holed:  ");
    PrintArrayPreview(vecHoled, vecSize, stdout);
    fprintf(stdout, "Array filled: ");
    PrintArrayPreview(vecFilled, vecSize, stdout);

    // CPU-side verification
    size_t nanCount = 0;
    for (size_t i = 0; i < vecSize; i++) {
        if (isnan(vecHoled[i])) {
            nanCount++;
            if (fabs((vecHoled[i - 1] + vecHoled[i + 1]) * 0.5 - vecFilled[i]) > 0.00001) {
                fprintf(stdout, "\033[91mArrays do not match! (@%llu %f, %f -> %f != %f)\n\033[0m", i, vecHoled[i - 1],
                        vecHoled[i + 1], vecHoled[i], vecFilled[i]);
                goto freeingReturn;
            }
        }
    }
    fprintf(stdout, "\033[92mArrays match (nancount=%llu)!\033[0m\n", nanCount);

// Freeing
freeingReturn:
    free(vecFilled);
    free(vecHoled);
}
