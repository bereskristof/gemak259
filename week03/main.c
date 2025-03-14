#include "main.h"

int main(int argc, char* argv[]) {
    const char* fileName = GetFileNameAlloc(argc, argv);
    FILE* file = fopen64(fileName, "rb");
    free((void*)fileName);
    if (file == NULL) {
        fprintf(stderr, "Failed to open file!\n");
        return FILE_NULL_ERROR;
    }

    int err = 0;
#ifndef USE_HOST
    const ulong matchedByteAmount = CountBytes_Device(&err, file);
#else
    const ulong matchedByteAmount = CountBytes_Host(&err, file);
#endif
    switch (err) {
        case READ_ERROR:
            fprintf(stderr, "Failed to read file, an error occured!\n");
            return err;
        case MAX_SIZE_ERROR:
            fprintf(stderr, "Did not read file, reached maximum size before EOF!\n");
            return err;
        default:
            break;
    }

    fprintf(stderr, "Found number of bytes matching 0x%02x:\n", COUNTED_BYTE);
    printf("%llu", matchedByteAmount);
    fprintf(stderr, "\n");
    fclose(file);
    return EXIT_SUCCESS;
}

char* GetFileNameAlloc(const int argc, char* const argv[]) {
    char* fileName;
    if (argc > 1) {
        const size_t fileNameCount = strlen(argv[1]) + 1;  // +1 for \0
        fileName = malloc(fileNameCount * sizeof(char));
        strcpy(fileName, argv[1]);
    } else {
        const char defaultFileName[] = "dummy_file.bin";
        fileName = malloc(sizeof(defaultFileName));
        strcpy(fileName, defaultFileName);
    }
    return fileName;
}

ulong CountBytes_Host(int* error, FILE* const file) {
    byte* block = malloc(BLOCK_SIZE * sizeof(byte));
    ulong matchedByteAmount = 0;
    size_t i = 0;
    while (i < MAX_BLOCKS) {
        i++;
        const size_t byteCount = fread(block, sizeof(byte), BLOCK_SIZE, file);
        if (byteCount == 0) {
            if (!feof(file)) {
                *error = READ_ERROR;
                free(block);
                return 0;
            }
            break;
        }
        matchedByteAmount += CountBlockBytes_Host(block, byteCount, COUNTED_BYTE);
    }
    free(block);
    if (i >= MAX_BLOCKS) {
        *error = MAX_SIZE_ERROR;
        return 0;
    }
    *error = SUCCESS;
    return matchedByteAmount;
}

ulong CountBlockBytes_Host(byte* const block, const size_t byteCount, const byte byteValue) {
    ulong count = 0;
    for (size_t i = 0; i < byteCount; i++) {
        if (block[i] == byteValue) {
            count++;
        }
    }
    return count;
}

ulong ArraySum_Host(ulong* const vec, const size_t vecSize) {
    ulong sum = 0;
    for (size_t i = 0; i < vecSize; i++) {
        sum += vec[i];
    }
    return sum;
}

ulong CountBytes_Device(int* error, FILE* const file) {
    enum UtilErr utilErr;
    struct ClContainer cl;

    // Create OpenCL container
    utilErr = InitClContainer(&cl);
    if (utilErr != UERR_NONE) {
        *error = utilErr;
        return 0;
    }

    // Load cl program
    utilErr = LoadClContainerProgram(&cl, "main.cl");
    if (utilErr != UERR_NONE) {
        *error = utilErr;
        return 0;
    }

    // Iterate every block
    int err = 0;
    const ulong matchedByteCount = IterateBlocks_Device(&err, &cl, file);
    if (err != SUCCESS) {
        *error = err;
        clReleaseProgram(cl.program);
        return 0;
    }

    clReleaseProgram(cl.program);

    return matchedByteCount;  // TODO: REPLACE
}

ulong IterateBlocks_Device(int* error, struct ClContainer* const cl, FILE* const file) {
    byte* block = malloc(BLOCK_SIZE * sizeof(byte));
    size_t i = 0;
    cl_event* events = malloc(MAX_BLOCKS * sizeof(cl_event));
    ulong* byteCountList = malloc(MAX_BLOCKS * sizeof(ulong));
    ulong returnValue = 0;

    while (i < MAX_BLOCKS) {
        const size_t byteCount = fread(block, sizeof(byte), BLOCK_SIZE, file);
        if (byteCount == 0) {
            if (!feof(file)) {
                *error = READ_ERROR;
                goto errReturn;
            }
            break;
        }
        // Enqueue block
        const int err = EnqueueCountBlockBytes_Device(&events[i], &byteCountList[i], cl, block, byteCount);
        if (err != SUCCESS) {
            *error = CL_ANY_ERROR;
            goto errReturn;
        }
        i++;
    }
    cl_int clErr;
    if ((clErr = clWaitForEvents(i, events)) != CL_SUCCESS) {
        PrintClErr("Did not wait for events!", clErr);
    }
    if (i >= MAX_BLOCKS) {
        *error = MAX_SIZE_ERROR;
        goto errReturn;
    }

    returnValue = ArraySum_Host(byteCountList, i);

errReturn:
    free(block);
    free(events);
    free(byteCountList);
    return returnValue;
}

int EnqueueCountBlockBytes_Device(cl_event* ev, ulong* n, cl_ptr const cl, const byte* block, const size_t count) {
    cl_int clErr;

    // Create kernel
    cl_kernel kernel = clCreateKernel(cl->program, "CountBytes", &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not create OpenCL buffer!", clErr);
        return CL_ANY_ERROR;
    }

    // Create block buffer
    const ulong zero = 0;
    cl_mem clRes =
        clCreateBuffer(cl->context, CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR, sizeof(zero), (void*)&zero, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not create OpenCL buffer!", clErr);
        return CL_ANY_ERROR;
    }
    cl_mem clBlock = clCreateBuffer(cl->context, CL_MEM_READ_ONLY | CL_MEM_USE_HOST_PTR, count, (void*)block, &clErr);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not create OpenCL buffer!", clErr);
        return CL_ANY_ERROR;
    }

    // Set kernel args
    clErr = clSetKernelArg(kernel, 0, sizeof(clRes), (void*)&clRes);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 1st OpenCL argument!", clErr);
        return CL_ANY_ERROR;
    }
    clErr = clSetKernelArg(kernel, 1, sizeof(clBlock), (void*)&clBlock);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 2nd OpenCL argument!", clErr);
        return CL_ANY_ERROR;
    }
    clErr = clSetKernelArg(kernel, 2, sizeof(count), (void*)&count);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not set 3rd OpenCL argument!", clErr);
        return CL_ANY_ERROR;
    }

    // Enqueue run
    const size_t workGroupSize = 256;
    const size_t workSize = 4096;
    clErr = clEnqueueNDRangeKernel(cl->queue, kernel, 1, NULL, &workSize, &workGroupSize, 0, NULL, NULL);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not start OpenCl kernel!", clErr);
        return CL_ANY_ERROR;
    }

    // Enqueue read
    clErr = clEnqueueReadBuffer(cl->queue, clRes, CL_FALSE, 0, sizeof(ulong), n, 0, NULL, ev);
    if (clErr != CL_SUCCESS) {
        PrintClErr("Could not read OpenCl buffer!", clErr);
        return CL_ANY_ERROR;
    }
    // Create callback
    // clSetEventCallback(*ev, CL_COMPLETE, (*CallbackCountBlockBytes_Device), (void*)n);

    return SUCCESS;
}

// void CL_CALLBACK CallbackCountBlockBytes_Device(cl_event event, cl_int status, void* userData) {}
