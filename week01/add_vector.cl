/*
 *  4. Vektorok összeadása
 *  * Készítsünk programot két valós vektor összeadására!
 *  * Szervezzük át a programot úgy, hogy a függvény hívásakor ne látszódjon,
 *    hogy OpenCL-es implementációról van szó!
 *  * Szekvenciális programmal ellenőríztessük az eredmény helyességét!
 */

#define THREADS_COUNT (1 << 10)

// Replaces 1st vector with the sum of the 2 vectors
// Assumes both arrays are smaller than arrayCount
__kernel void VectorAdd(__global float* a, __global float* b, int arrayCount) {
    const int id = get_global_id(0);
    int currentIndex = id;
    while (currentIndex < arrayCount) {
        a[currentIndex] += b[currentIndex];
        currentIndex += THREADS_COUNT;
    }
}
