#ifndef MAINH_C
#define MAINH_C

#include <utils.h>

void PanicAndQuit(const char messageFormat[], const int code) __attribute__((noreturn));

void MatrixMultCl(const int vecA[], const int vecB[], int vecResult[], const size_t vecSize);
bool TestVectorAdd(const int a[], const int b[], const int result[], const size_t vecSize);

#endif  // MAINH_C
