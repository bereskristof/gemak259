__kernel void VectorAdd(__global int* a, __global int* b, __global int* result, int n) {
    const int i = get_global_id(0);
    if (i < n) {
        result[i] = a[i] + b[i];
    }
}
