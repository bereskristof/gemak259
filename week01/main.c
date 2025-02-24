#include "main.h"

#define ARRAY_SIZE (1 << 14)
#define LOCAL_WORK_SIZE (1 << 8)
#define ARRAY_MAX_FLOAT 500.0f
#define SUB_COUNT 2

int main(void) {
    // Generate data array
    float* array1 = malloc(ARRAY_SIZE * sizeof(int));
    FillArrayRandom(array1, ARRAY_SIZE, 5001);
    float* array2 = malloc(ARRAY_SIZE * sizeof(int));
    FillArrayRandom(array2, ARRAY_SIZE, 5003);
    fprintf(stderr, "Created random arrays (range=0f...%.0ff)\n", ARRAY_MAX_FLOAT);
    fprintf(stderr, "Array 1: ");
    PrintArrayPreview(array1, ARRAY_SIZE);
    fprintf(stderr, "Array 2: ");
    PrintArrayPreview(array2, ARRAY_SIZE);

    // Create OpenCL container
    enum UtilErr utilReturn;
    struct ClProgramContainer cl = InitClContainer(&utilReturn);
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
            default:
                break;
        }
    }

    // Free resources
    // TODO: Free container
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

// Gets a random float between 0 and 1
float GetRandomFloat() {
    return (float)rand() / RAND_MAX;
}

// Print a preview of an array
// Assumes the array is at least 8 items long
void PrintArrayPreview(const float* const array, const size_t arraySize) {
    fprintf(stderr, "[");
    for (size_t i = 0; i < 4; i++) {
        fprintf(stderr, "%6.2ff, ", array[i]);
    }
    fprintf(stderr, "..., ");
    for (size_t i = arraySize - 3; i < arraySize - 1; i++) {
        fprintf(stderr, "%6.2ff, ", array[i]);
    }
    fprintf(stderr, "%6.2ff]\n", array[arraySize - 1]);
}

// Creates and returns a new CL container
// Sets success to a non 0 value if it failed
struct ClProgramContainer InitClContainer(enum UtilErr* utilSuccess) {
    struct ClProgramContainer cl;
    enum UtilErr utilReturn;
    utilReturn = InitCl(&cl.platform, &cl.device, &cl.context, &cl.queue);
    *utilSuccess = (int)utilReturn;
    return cl;
}

// Loads the provided function from the provided file into the kernel of the CL container
enum UtilErr LoadClContainerKernel(struct ClProgramContainer* cl, const char filePath[], const char functionName[]) {
    enum UtilErr utilReturn;
    cl_int clReturn;
    utilReturn = LoadClProgram(&cl->program, filePath, &cl->device, &cl->context);
    if (utilReturn != UERR_NONE) {
        return utilReturn;
    }
    cl->kernel = clCreateKernel(cl->program, functionName, &clReturn);
    if (clReturn != CL_SUCCESS) {
        PrintErr("Creating GetArrayMin kernel failed (%d)", clReturn);
        return UERR_CL_CREATE_PROGRAM_FAILED;  // TODO: Replace with proper error
    }
    return UERR_NONE;
}

// Returns the read number or -1
int GetInputInt(void) {
    printf("\033[104;30m Select a function \033[0m\n");
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
