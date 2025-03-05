#ifndef MAIN_C
#define MAIN_C

#include <math.h>
#include <utils.h>

#define F32_EPSYLON 0.0001
#define fallthrough [[fallthrough]]
#define nonnull __attribute__((nonnull))
#define min(a, b) (((a) < (b)) ? (a) : (b))

// Simple matrix object
// Uses row-major ordering
// ```
// |0 1 2|
// |3 4 5|
// |6 7 8|
// ```
typedef struct Matrix {
    struct MatrixSize {
        unsigned int x;
        unsigned int y;
    } size;
    float* items;
} Matrix;

enum MatrixCalcOp {
    MXCLOP_TRANSPOSE,
    MXCLOP_MULTIPLY,
    MXCLOP_ROWSUM,
    MXCLOP_COLSUM,
};

int GetInputInt(void);
Matrix AllocMatrix(const unsigned int width, const unsigned int height);
nonnull static inline void SetMatrix(Matrix* const matrix,
                                     const unsigned int row,
                                     const unsigned int column,
                                     const float newValue);
nonnull static inline float GetMatrix(const Matrix* matrix, const unsigned int row, const unsigned int column);
nonnull void RandomFillMatrix(Matrix* const matrix, const unsigned int seed);
static inline float GetRandomFloat();
void PreviewMatrix(const Matrix matrix);
nonnull void FreeMatrix(Matrix* const matrix);
void MatrixCalc(const enum MatrixCalcOp op, struct ClContainer* cl, const Matrix m1, const Matrix m2);
nonnull static bool VerifyTranspose(const Matrix* m1, const Matrix* mr);
nonnull static bool VerifyMultiply(const Matrix* m1, const Matrix* m2, const Matrix* mr);
nonnull static bool VerifyRowSum(const Matrix* m1, const Matrix* mr);
nonnull static bool VerifyColSum(const Matrix* m1, const Matrix* mr);

#endif  // MAIN_C
