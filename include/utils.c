#include "utils.h"

// Loads the contents of the text file at `filePath` into `textBuffer`.
// Known issues: Failes if the target file is empty
enum UtilErr LoadTextFile(char* const textBuffer, const size_t textBufferSize, const char filePath[]) {
    FILE* const file = fopen(filePath, "r");
    if (file == NULL)
        return UERR_FILE_IO_FAILED;
    const size_t readChars = fread(textBuffer, sizeof(char), textBufferSize, file);
    const int lastCharIndex = ((textBufferSize - 1) > readChars) ? readChars : (textBufferSize - 1);
    int returnValue = UERR_NONE;
    if (textBuffer[lastCharIndex] != '\0')
        returnValue = UERR_BUFFER_OVERFLOW;
    fclose(file);
    return returnValue;
}
