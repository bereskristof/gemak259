#include "main.h"

#include "add_vector.c"
#include "interpolate_vector.c"

int main(void) {
    // Generate data array
    float* array1 = malloc(ARRAY_SIZE * sizeof(int));
    FillArrayRandom(array1, ARRAY_SIZE, 5001);
    float* array2 = malloc(ARRAY_SIZE * sizeof(int));
    FillArrayRandom(array2, ARRAY_SIZE, 5003);
    fprintf(stderr, "Created random arrays (range=0f...%.0ff)\n", ARRAY_MAX_FLOAT);
    fprintf(stderr, "Array 1: ");
    PrintArrayPreview(array1, ARRAY_SIZE, stderr);
    fprintf(stderr, "Array 2: ");
    PrintArrayPreview(array2, ARRAY_SIZE, stderr);

    // Create OpenCL container
    enum UtilErr utilReturn;
    struct ClContainer cl;
    globalUtilConf.initClPrintLog = true;
    utilReturn = InitClContainer(&cl);
    if (utilReturn != UERR_NONE)
        return utilReturn;
    fprintf(stderr, "Set up OpenCL context successfully!\n");

    // Get requested sub-program
    bool shouldClose = false;
    while (!shouldClose) {
        const int subprogramId = GetInputInt();
        switch (subprogramId) {
            case 0:
                shouldClose = true;
                break;
            case 1:
                SubroutineAddVectors(&cl, array1, array2, ARRAY_SIZE);
                break;
            case 2:
                SubroutineInterpolateVectors(&cl, array1, ARRAY_SIZE);
                break;
            default:
                break;
        }
    }

    // Free resources
    FreeClContainer(&cl);
    free(array2);
    free(array1);
    fprintf(stderr, "Resources freed, no errors occured!\n");
    return 0;
}

// Fills the provided array with random data in range [0f, ARRAY_MAX_FLOAT]
void FillArrayRandom(float* array, const size_t arraySize, const unsigned int seed) {
    srand(seed);                              // Same seed is used to keep separate runs the same
    rand();                                   // Throws away first value, as they are too similar with low seed deltas
    for (size_t i = 0; i < arraySize; i++) {  // Randomly fills array with data
        array[i] = GetRandomFloat() * ARRAY_MAX_FLOAT;
    }
}

// Randomly "removes" items from an array (sets it to NA)
// All empty items are guaranteed to have neighbours
void HoleArrayRandom(float* array, const size_t arraySize, const unsigned int seed) {
    srand(seed);  // Same seed is used to keep separate runs the same
    rand();       // Throws away first value, as they are too similar with low seed deltas
    size_t i = rand() % 30 + 1;
    while (i < arraySize - 1) {
        array[i] = NAN;
        i += rand() % 30 + 2;
    }
}

// Gets a random float between 0 and 1
float GetRandomFloat() {
    return (float)rand() / RAND_MAX;
}

// Print a preview of an array
// Assumes the array is at least 8 items long
void PrintArrayPreview(const float* const array, const size_t arraySize, FILE* stream) {
    fprintf(stream, "[");
    for (size_t i = 0; i < 4; i++) {
        fprintf(stream, "%6.2ff, ", array[i]);
    }
    fprintf(stream, "..., ");
    for (size_t i = arraySize - 3; i < arraySize - 1; i++) {
        fprintf(stream, "%6.2ff, ", array[i]);
    }
    fprintf(stream, "%6.2ff]\n", array[arraySize - 1]);
}

// Returns the read number or -1
int GetInputInt(void) {
    printf("\033[104;30m Select a function \033[0m\n");
    printf("1. Add vectors\n");
    printf("2. Interpolate vectors\n");
    printf("0. Exit\n");
    printf("> ");
    int selection = -1;
    int scanReturn = 0;
    scanReturn = scanf(" %d", &selection);
    char c;
    do
        c = getchar();
    while (c != '\n' && c != EOF);  // Buffer flush
    if (scanReturn != 1)
        return -1;
    return selection;
}
