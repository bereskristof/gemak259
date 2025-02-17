#ifndef MAINH_C
#define MAINH_C

#include <utils.h>

void PanicAndQuit(const char messageFormat[], const int code) __attribute__((noreturn));

void PrintClPlatforms(const size_t count, cl_platform_id ids[]);
void PrintClDevices(const size_t count, cl_device_id ids[]);

bool TestVectorAdd(const int a[], const int b[], const int result[], const size_t vecSize);

#endif // MAINH_C
