// Destructively makes the vectors first element its smallest
// NOTE: Due to barrier, only a single workgroup may be used
__kernel void VectorMin(__global int* vector, const int vectorSize, const int threadCount) {
    const int id = get_global_id(0);
    const int maxDepth = (int)(ceil(log2((float)vectorSize)));
    for (int d = 0; d < maxDepth; d++) {
        const int step = (int)(pow(2.0f, d));
        for (int cell = id * 2; cell < vectorSize; cell += threadCount) {
            const int leftCell = cell;
            const int rightCell = cell + step;
            if (id % step == 0) {
                vector[leftCell] = vector[leftCell] < vector[rightCell] ? vector[leftCell] : vector[rightCell];
            }
        }
        work_group_barrier(CLK_LOCAL_MEM_FENCE);
    }
}

// Destructively makes the vectors first element its largest
// NOTE: Due to barrier, only a single workgroup may be used
__kernel void VectorMax(__global int* vector, const int vectorSize, const int threadCount) {
    const int id = get_global_id(0);
    const int maxDepth = (int)(ceil(log2((float)vectorSize)));
    for (int d = 0; d < maxDepth; d++) {
        const int step = (int)(pow(2.0f, d));
        for (int cell = id * 2; cell < vectorSize; cell += threadCount) {
            const int leftCell = cell;
            const int rightCell = cell + step;
            if (id % step == 0) {
                vector[leftCell] = vector[leftCell] > vector[rightCell] ? vector[leftCell] : vector[rightCell];
            }
        }
        work_group_barrier(CLK_LOCAL_MEM_FENCE);
    }
}
