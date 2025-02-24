/*
 *  4. Vektorok összeadása
 *  * Tegyük fel, hogy egy nemnegatív egészeket tartalmazó tömbből elszórtan hiányoznak elemek.
 *    Pótoljuk ezeket a szomszédos elemek átlagával!
 *  * Feltételezzük, hogy a hiányzó elemek mindkét szomszéd ismert.
 *  * Készítsünk függvényt, amelyik ilyen bemenetet tud előállítani!
 */

#define THREADS_COUNT (1 << 10)

// Replaces NANs with interpolated values (average)
// Assumes array is smaller than arrayCount
__kernel void VectorFill(__global float* a, int arrayCount) {
    const int id = get_global_id(0);
    int currentIndex = id;
    while (currentIndex < arrayCount) {
        if (isnan(a[currentIndex])) {
            a[currentIndex] = (a[currentIndex - 1] + a[currentIndex + 1]) * 0.5;
        }
        currentIndex += THREADS_COUNT;
    }
}
