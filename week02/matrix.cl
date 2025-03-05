/*
 *  Mátrix műveletek
 *  Implementáljuk a következő mátrix műveleteket OpenCL segítségével!
 *  * Transzponálás
 *  * Szorzás
 *  * Oszlopösszeg számítás
 *  * Sorösszeg számítás
 */

// Converts row, col definition to row-major ordered index
int GetPos(__private uint row, __private uint col, __private uint2 size) {
    return row * size.x + col;
}

// Transposes row-major ordered matrix `m` sized `s` and writes it to `mt`
__kernel void TransposeMatrix(__global float* mt, __constant float* m, __private uint2 s) {
    const int id = get_global_id(0);
    const unsigned int w = s.x;
    const unsigned int h = s.y;
    if (id >= w * h)
        return;
    const int y = id / w;
    const int x = id - y * w;
    mt[y + x * h] = m[id];
}

// Multiplies two row-major ordered matrices `m1` with `m2` sized `s1` and `s2` and writes the result to `mm`
__kernel void MultiplyMatrix(__global float* mm,
                             __constant float* m1,
                             __private uint2 s1,
                             __constant float* m2,
                             __private uint2 s2) {
    const int id = get_global_id(0);
    const unsigned int w = s2.x;
    const unsigned int h = s1.y;
    const unsigned int d = s2.y;
    if (id >= w * h)
        return;
    const int y = id / w;
    const int x = id - y * w;
    float result = 0.0f;
    for (uint i = 0; i < d; i++) {
        result += m1[GetPos(y, i, s1)] * m2[GetPos(i, x, s2)];
    }
    mm[id] = result;
}

// Adds up row-major ordered matrix `m`s rows sized `s` and writes it to `mr`
__kernel void RowSumMatrix(__global float* mr, __constant float* m, __private uint2 s) {
    const int id = get_global_id(0);
    const unsigned int w = s.x;
    const unsigned int h = s.y;
    if (id >= h)
        return;
    float result = 0.0f;
    for (uint i = 0; i < w; i++) {
        result += m[GetPos(id, i, s)];
    }
    mr[id] = result;
}

// Adds up row-major ordered matrix `m`s columns sized `s` and writes it to `mc`
__kernel void ColSumMatrix(__global float* mc, __constant float* m, __private uint2 s) {
    const int id = get_global_id(0);
    const unsigned int w = s.x;
    const unsigned int h = s.y;
    if (id >= w)
        return;
    float result = 0.0f;
    for (uint i = 0; i < h; i++) {
        result += m[GetPos(i, id, s)];
    }
    mc[id] = result;
}
