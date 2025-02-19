// Destructively makes the arrays first element its smallest
// NOTE: Due to barrier, only a single workgroup may be used
__kernel void GetArrayMin(__global int* array, const int arraySize, const int threadCount) {
    const int id = get_global_id(0);
    const int maxDepth = (int)(ceil(log2((float)arraySize)));
    for (int d = 0; d < maxDepth; d++) {
        const int step = (int)(pow(2.0f, d));
        for (int cell = id * 2; cell < arraySize; cell += threadCount) {
            const int leftCell = cell;
            const int rightCell = cell + step;
            if (id % step == 0) {
                array[leftCell] = array[leftCell] < array[rightCell] ? array[leftCell] : array[rightCell];
            }
        }
        work_group_barrier(CLK_LOCAL_MEM_FENCE);
    }
}

// Destructively makes the arrays first element its largest
// NOTE: Due to barrier, only a single workgroup may be used
__kernel void GetArrayMax(__global int* array, const int arraySize, const int threadCount) {
    const int id = get_global_id(0);
    const int maxDepth = (int)(ceil(log2((float)arraySize)));
    for (int d = 0; d < maxDepth; d++) {
        const int step = (int)(pow(2.0f, d));
        for (int cell = id * 2; cell < arraySize; cell += threadCount) {
            const int leftCell = cell;
            const int rightCell = cell + step;
            if (id % step == 0) {
                array[leftCell] = array[leftCell] > array[rightCell] ? array[leftCell] : array[rightCell];
            }
        }
        work_group_barrier(CLK_LOCAL_MEM_FENCE);
    }
}
