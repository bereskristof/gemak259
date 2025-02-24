#ifndef MAIN_C
#define MAIN_C

#include <math.h>
#include <utils.h>

#define THREADS_COUNT (1 << 10)
#define ARRAY_SIZE (1 << 12)
#define LOCAL_WORK_SIZE (1 << 8)
#define ARRAY_MAX_FLOAT 500.0f
#define SUB_COUNT 2

void FillArrayRandom(float* array, const size_t arraySize, const unsigned int seed);
void HoleArrayRandom(float* array, const size_t arraySize, const unsigned int seed);
float GetRandomFloat();
void PrintArrayPreview(const float* const array, const size_t arraySize, FILE* stream);
int GetInputInt(void);
void SubroutineAddVectors(struct ClContainer* cl, float vec1[], float vec2[], const size_t vecSize);

#endif  // MAIN_C
