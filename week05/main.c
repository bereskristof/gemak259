#include "main.h"

void printArray(const uint *array, const size_t count) {
    for (size_t i = 0; i < __min(16, count); i++) {
        fprintf(stderr, "%u, ", array[i]);
    }
    fprintf(stderr, "\n");
}

int main(void) {
    const size_t array_size = (1 << 10) * 16;  // 16 KiB
    uint *unsorted = malloc(sizeof(unsorted[0]) * array_size);
    uint *sorted = malloc(sizeof(sorted[0]) * array_size);

    fillArrayAscending(unsorted, array_size);
    shuffleArray(unsorted, array_size);
    memcpy(sorted, unsorted, sizeof(unsorted[0]) * array_size);

    const result err = sortArray(sorted, array_size);
    if (err != success) {
        return EXIT_FAILURE;
    }

    printArray(unsorted, array_size);
    printArray(sorted, array_size);

    const bool is_correct = verifySort(sorted, unsorted, array_size);
    fprintf(stderr, "Is array sorted? %s\n", is_correct ? "Yes" : "No");

    free(unsorted);
    free(sorted);
    return EXIT_SUCCESS;
}

void fillArrayAscending(uint array[], const size_t count) {
    for (size_t i = 0; i < count; i++) {
        array[i] = i;
    }
}

void shuffleArray(uint array[], const size_t count) {
    for (size_t i = 0; i < count; i++) {
        size_t pick = getRandomRange(i, count - 1);
        const int swap = array[i];
        array[i] = array[pick];
        array[pick] = swap;
    }
}

size_t getRandomRange(const size_t lower, const size_t upper) {
    static bool ready = false;
    if (!ready) {
        srand(rand_seed);
        ready = true;
    }
    return (size_t)rand() % (upper + 1 - lower) + lower;
}

result sortArray(uint *array, const size_t count) {
    struct ClContainer cl;
    result err;
    cl_mem cl_array;

    err = setupKernel(&cl);
    if (err != success) {
        return failure;
    }
    err = setupBuffer(&cl, &cl_array, array, count);
    if (err != success) {
        return failure;
    }
    err = setupSortArgs(&cl, &cl_array, count);
    if (err != success) {
        return failure;
    }
    err = runSort(&cl, &cl_array, array, count);
    if (err != success) {
        return failure;
    }

    return success;
}

result setupKernel(struct ClContainer *cl) {
    enum UtilErr err;

    err = InitClContainer(cl);
    if (err != UERR_NONE) {
        return failure;
    }
    err = LoadClContainerKernel(cl, "sort.cl", "sortArray");
    if (err != UERR_NONE) {
        return failure;
    }

    return success;
}

result setupBuffer(struct ClContainer *cl, cl_mem *cl_array, uint *array, const size_t count) {
    cl_int err;
    const size_t array_bytes = count * sizeof(array[0]);

    const cl_mem_flags flags = CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR;
    *cl_array = clCreateBuffer(cl->context, flags, array_bytes, array, &err);
    if (err != CL_SUCCESS) {
        PrintClErr("Could not create array buffer", err);
        return failure;
    }

    return success;
}

result setupSortArgs(struct ClContainer *cl, cl_mem *cl_array, const size_t count) {
    cl_int err;
    const cl_ulong cl_count = (cl_ulong)count;

    err = clSetKernelArg(cl->kernel, 0, sizeof(cl_array), cl_array);
    if (err != CL_SUCCESS) {
        PrintClErr("Could not set array argument", err);
        return failure;
    }
    err = clSetKernelArg(cl->kernel, 1, sizeof(cl_count), &cl_count);
    if (err != CL_SUCCESS) {
        PrintClErr("Could not set size argument", err);
        return failure;
    }

    return success;
}

result runSort(struct ClContainer *cl, cl_mem *cl_array, uint *result, const size_t count) {
    cl_int err;
    const size_t array_bytes = count * sizeof(result[0]);
    const size_t total_size = getNextPowerOfTwo(count);
    fprintf(stderr, "Total size: %llu\n", total_size);
    const size_t work_size = __min(total_size, 512);

    err = clEnqueueNDRangeKernel(cl->queue, cl->kernel, 1, NULL, &total_size, &work_size, 0, NULL, NULL);
    if (err != CL_SUCCESS) {
        PrintClErr("Failed to execute kernel", err);
        return failure;
    }
    err = clEnqueueReadBuffer(cl->queue, *cl_array, CL_TRUE, 0, array_bytes, (void *)result, 0, NULL, NULL);
    if (err != CL_SUCCESS) {
        PrintClErr("Failed to read result from device", err);
        return failure;
    }

    return success;
}

// WARNING: The number may not have it's first bit as 1, or be 0
size_t getNextPowerOfTwo(const size_t number) {
    const unsigned long long leading_zeroes = __builtin_ia32_lzcnt_u64(number - 1);
    return ((unsigned long long)1 << 63) >> (leading_zeroes - 1);
}

bool verifySort(const uint sorted[], const uint unsorted[], const size_t count) {
    const bool is_sorted = checkSorted(sorted, count);
    const bool is_equal = checkItemsEqual(sorted, unsorted, count);
    return is_sorted & is_equal;
}

bool checkSorted(const uint sorted[], const size_t count) {
    uint value = 0;
    for (size_t i = 0; i < count; i++) {
        const uint new = sorted[i];
        if (new < value) {
            return false;
        }
        value = new;
    }
    return true;
}

bool checkItemsEqual(const uint array1[], const uint array2[], const size_t count) {
    uint *counter_array1 = calloc(count, sizeof(counter_array1[0]));
    uint *counter_array2 = calloc(count, sizeof(counter_array2[0]));
    countIntegers(counter_array1, array1, count);
    countIntegers(counter_array2, array2, count);
    const size_t count_byte = (sizeof(counter_array1[0]) / sizeof(char)) * count;
    const int equal = memcmp(counter_array1, counter_array2, count_byte);
    free(counter_array1);
    free(counter_array2);
    return equal == 0;
}

void countIntegers(uint counter[], const uint array[], const uint count) {
    for (size_t i = 0; i < count; i++) {
        const uint v = array[i];
        if (v >= count) {
            fprintf(stderr, "Error: item %d at %lld outside range 0-%d\n", v, i, count);
            exit(EXIT_FAILURE);
        }
        counter[v]++;
    }
}
