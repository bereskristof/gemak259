#ifndef MAIN_C
#define MAIN_C

#include <stdio.h>
#include <stdlib.h>
#include <utils.h>

#ifndef RAND_SEED
#define RAND_SEED 50
#endif

const unsigned int rand_seed = RAND_SEED;

typedef unsigned int uint;

void fillArrayAscending(uint array[], const size_t count);
void shuffleArray(uint array[], const size_t count);
size_t getRandomRange(const size_t lower, const size_t upper);
bool verifySort(const uint sorted[], const uint unsorted[], const size_t count);
bool checkSorted(const uint sorted[], const size_t count);
bool checkItemsEqual(const uint array1[], const uint array2[], const size_t count);
void countIntegers(uint counter[], const uint array[], const uint count);

#endif  // MAIN_C
