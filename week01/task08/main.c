/*
 *  8. Szélsőérték vizsgálat
 *  * Számoljuk ki konstans időben egy tömb minimumát/maximumát!
 *  * Próbáljuk meg minimalizálni a felhasznált processzormagok számát!
 */

#include "main.h"

#define ARRAY_SIZE (1 << 14)
#define LOCAL_WORK_SIZE (1 << 8)
#define ARRAY_MAX_DELTA 12500

int main(void) {
    int* array = malloc(ARRAY_SIZE * sizeof(int));
    FillArrayRandom(array, ARRAY_SIZE);
    printf("Created array (range=%d...%d)\n", -ARRAY_MAX_DELTA, ARRAY_MAX_DELTA);

    // Find values sequentially for comparison
    bool isMinUnique = false;
    int minIndex = 0;
    int cpuMin = GetArrayMin(&minIndex, &isMinUnique, array, ARRAY_SIZE);
    printf("CPU minimum: %d@%d (unique=%s)\n", cpuMin, minIndex, isMinUnique ? "Y" : "N");
    bool isMaxUnique = false;
    int maxIndex = 0;
    int cpuMax = GetArrayMax(&maxIndex, &isMaxUnique, array, ARRAY_SIZE);
    printf("CPU maximum: %d@%d (unique=%s)\n", cpuMax, maxIndex, isMaxUnique ? "Y" : "N");

    enum UtilErr utilReturn;
    struct ClProgramContainer cl;

    // Sets up OpenCL
    cl_int clReturn;
    utilReturn = InitCl(&cl.platform, &cl.device, &cl.context, &cl.queue);
    if (utilReturn != UERR_NONE)
        return utilReturn;
    utilReturn = LoadClProgram(&cl.program, "./minmax.cl", &cl.device, &cl.context);
    if (utilReturn != UERR_NONE)
        return utilReturn;
    cl.kernels[0] = clCreateKernel(cl.program, "GetArrayMin", &clReturn);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Creating GetArrayMin kernel failed (%d)", clReturn);
        return clReturn;
    }
    cl.kernels[1] = clCreateKernel(cl.program, "GetArrayMax", &clReturn);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Creating GetArrayMax kernel failed (%d)", clReturn);
        return clReturn;
    }

    // Sets up args for min kernel
    const int arraySize = ARRAY_SIZE;
    const size_t arrayByteSize = arraySize * sizeof(int);
    const size_t globalWork = LOCAL_WORK_SIZE;  // Device code requires that a single workgroup is used
    const int localWorkInt = LOCAL_WORK_SIZE;
    const size_t localWorkSize = LOCAL_WORK_SIZE;
    cl_mem deviceArrayMin = clCreateBuffer(cl.context, CL_MEM_READ_WRITE, arrayByteSize, NULL, &clReturn);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Creating device array failed [min] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clSetKernelArg(cl.kernels[0], 0, sizeof(deviceArrayMin), (void*)&deviceArrayMin);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Setting up kernel argument 0 failed [min] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clSetKernelArg(cl.kernels[0], 1, sizeof(int), (void*)&arraySize);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Setting up kernel argument 1 failed [min] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clSetKernelArg(cl.kernels[0], 2, sizeof(int), (void*)&localWorkInt);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Setting up kernel argument 2 failed [min] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clEnqueueWriteBuffer(cl.queue, deviceArrayMin, CL_FALSE, 0, arrayByteSize, (void*)array, 0, NULL, NULL);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Couldn't copy host buffer to device [min] (%d)", clReturn);
        return clReturn;
    }

    // Sets up args for max kernel
    cl_mem deviceArrayMax = clCreateBuffer(cl.context, CL_MEM_READ_WRITE, arrayByteSize, NULL, &clReturn);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Creating device array failed [max] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clSetKernelArg(cl.kernels[1], 0, sizeof(deviceArrayMax), (void*)&deviceArrayMax);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Setting up kernel argument 0 failed [max] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clSetKernelArg(cl.kernels[1], 1, sizeof(int), (void*)&arraySize);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Setting up kernel argument 1 failed [max] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clSetKernelArg(cl.kernels[1], 2, sizeof(int), (void*)&localWorkInt);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Setting up kernel argument 2 failed [max] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clEnqueueWriteBuffer(cl.queue, deviceArrayMax, CL_FALSE, 0, arrayByteSize, (void*)array, 0, NULL, NULL);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Couldn't copy host buffer to device [max] (%d)", clReturn);
        return clReturn;
    }

    // Runs kernels
    clReturn = clEnqueueNDRangeKernel(cl.queue, cl.kernels[0], 1, NULL, &globalWork, &localWorkSize, 0, NULL, NULL);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Failed to run kernel 0 (%d)", clReturn);
        return clReturn;
    }
    clReturn = clEnqueueNDRangeKernel(cl.queue, cl.kernels[1], 1, NULL, &globalWork, &localWorkSize, 0, NULL, NULL);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Failed to run kernel 1 (%d)", clReturn);
        return clReturn;
    }

    // Get results
    // While the device modified most of the array, only the 1st item is relevant
    int gpuMin, gpuMax;
    clReturn = clEnqueueReadBuffer(cl.queue, deviceArrayMin, CL_TRUE, 0, sizeof(int), (void*)&gpuMin, 0, NULL, NULL);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Couldn't copy device buffer to host [min] (%d)", clReturn);
        return clReturn;
    }
    clReturn = clEnqueueReadBuffer(cl.queue, deviceArrayMax, CL_TRUE, 0, sizeof(int), (void*)&gpuMax, 0, NULL, NULL);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Couldn't copy device buffer to host [max] (%d)", clReturn);
        return clReturn;
    }
    printf("GPU minimum: %d\n", gpuMin);
    printf("GPU maximum: %d\n", gpuMax);

    clReleaseKernel(cl.kernels[1]);
    clReleaseKernel(cl.kernels[0]);
    clReleaseProgram(cl.program);
    clReleaseContext(cl.context);
    clReleaseDevice(cl.device);
    free(array);

    printf("All done!\n");
    return 0;
}

// Fills the provided array with random data in range [-ARRAY_MAX_DELTA, ARRAY_MAX_DELTA]
void FillArrayRandom(int* array, const size_t arraySize) {
    srand(5001);                              // Same seed is used to keep separate runs the same
    for (size_t i = 0; i < arraySize; i++) {  // Randomly fills array with data
        array[i] = (rand() % (2 * ARRAY_MAX_DELTA + 1)) - ARRAY_MAX_DELTA;
    }
}

// Sequentially gets the arrays minimum value
int GetArrayMin(int* index, bool* isUnique, const int* array, const size_t arraySize) {
    int min = array[0];
    *isUnique = true;
    for (size_t i = 1; i < arraySize; i++) {
        if (array[i] < min) {
            min = array[i];
            *index = i;
            *isUnique = true;
        } else if (array[i] == min) {
            *isUnique = false;
        }
    }
    return min;
}

// Sequentially gets the arrays maximum value
int GetArrayMax(int* index, bool* isUnique, const int* array, const size_t arraySize) {
    int max = array[0];
    *isUnique = true;
    for (size_t i = 1; i < arraySize; i++) {
        if (array[i] > max) {
            max = array[i];
            *index = i;
            *isUnique = true;
        } else if (array[i] == max) {
            *isUnique = false;
        }
    }
    return max;
}
