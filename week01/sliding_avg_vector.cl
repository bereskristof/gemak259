/*
 *  Csúszóátlag számítása
 *  * Egy valós vektor minden eleméhez számítsuk ki az adott környezeten (sugáron)
 *    belül lévő átlagot!
 */

// Calculates an average in range, using naive implemetation
__kernel void VectorSAvg(__global float* vector, __global float* results, const int vectorSize, const int threadCount) {
    int range = 16;
    int id = get_global_id(0);
    for (int i = id; i < vectorSize; i += threadCount) {
        float total = 0.0f;
        float count = 0.0f;
        for (int r = -(range - 1); r < range; r++) {
            if (r < 0 || r >= vectorSize)
                continue;
            total += vector[i + r];
            count += 1.0f;
        }
        results[i] = total / count;
    }
}
