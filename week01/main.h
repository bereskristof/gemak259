#ifndef MAIN_C
#define MAIN_C

#include <utils.h>

void FillArrayRandom(float* array, const size_t arraySize, const unsigned int seed);
float GetRandomFloat();
void PrintArrayPreview(const float* const array, const size_t arraySize);
struct ClProgramContainer InitClContainer(enum UtilErr* utilSuccess);
enum UtilErr LoadClContainerKernel(struct ClProgramContainer* cl, const char filePath[], const char functionName[]);
int GetInputInt(void);

#endif  // MAIN_C
