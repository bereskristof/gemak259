#include "main.h"

int main(void) {
    const size_t array_size = (1 << 10) * 16;  // 16 KiB
    uint* unsorted = malloc(sizeof(unsorted[0]) * array_size);
    uint* sorted = malloc(sizeof(sorted[0]) * array_size);

    fillArrayAscending(unsorted, array_size);
    fillArrayAscending(sorted, array_size);
    shuffleArray(unsorted, array_size);

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
    uint* counter_array1 = calloc(count, sizeof(counter_array1[0]));
    uint* counter_array2 = calloc(count, sizeof(counter_array2[0]));
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
