#ifndef COUNTED_BYTE
#define COUNTED_BYTE (uchar)(0x00)
#endif

#ifndef WORK_SIZE
#define WORK_SIZE 4096
#endif

// Gets
__kernel void CountBytes(__global uint* count, __global uchar* block, __private ulong blockSize) {
    const int id = get_global_id(0);
    for (int i = id; i < blockSize; i += WORK_SIZE) {
        if (block[i] == COUNTED_BYTE) {
            atomic_inc(count);
        }
    }
}
