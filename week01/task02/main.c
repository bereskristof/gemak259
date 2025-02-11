/*
 *  2. Kódbetöltő készítése
 *  * Készítsünk egy programrészt, amelyik a kernel forráskódját
 *    egy cl kiterjesztésű szöveges fájlból olvassa be!
 */

#include <utils.h>

int main(void) {
    const size_t bufferSize = 10;
    char data[bufferSize] = {};
    const enum UtilErr returnValue = LoadTextFile(data, bufferSize, "./test.txt");
    if (returnValue != UERR_NONE) {
        printf("File load error: %d\n", returnValue);
        return 1;
    }
    for (size_t i = 0; i < bufferSize; i++)
        printf("%d ", data[i]);
    return 0;
}
