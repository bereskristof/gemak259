#include "main.h"

int main(int argc, char* argv[]) {
    // Check if verbose
    bool verbose = false;
    if (argc > 1 && strcmp(argv[1], "-v") == 0)
        verbose = true;

    // Generate matricies
    Matrix m1 = AllocMatrix(128, 96);
    Matrix m2 = AllocMatrix(96, 128);
    RandomFillMatrix(&m1, 128);
    RandomFillMatrix(&m2, 129);

    fprintf(stderr, "Matrix 1 (Size: %ux%u):\n", m1.size.x, m1.size.y);
    PreviewMatrix(m1);
    fprintf(stderr, "Matrix 2 (Size: %ux%u):\n", m2.size.x, m2.size.y);
    PreviewMatrix(m2);

    // Create OpenCL container
    enum UtilErr utilReturn;
    struct ClContainer cl;
    if (verbose)
        globalUtilConf.initClPrintLog = true;
    utilReturn = InitClContainer(&cl);
    if (utilReturn != UERR_NONE)
        return utilReturn;
    if (verbose)
        fprintf(stderr, "Set up OpenCL context successfully!\n");

    // Get requested sub-program
    bool shouldClose = false;
    while (!shouldClose) {
        const int subprogramId = GetInputInt();
        switch (subprogramId) {
            case 0:
                shouldClose = true;
                break;
            case 1:
                MatrixCalc(MXCLOP_TRANSPOSE, &cl, m1, m2);
                break;
            case 2:
                MatrixCalc(MXCLOP_MULTIPLY, &cl, m1, m2);
                break;
            case 3:
                MatrixCalc(MXCLOP_MULTIPLY, &cl, m2, m1);
                break;
            case 4:
                MatrixCalc(MXCLOP_ROWSUM, &cl, m1, m2);
                break;
            case 5:
                MatrixCalc(MXCLOP_COLSUM, &cl, m1, m2);
                break;
            default:
                break;
        }
    }

    // Free resources
    FreeClContainer(&cl);
    FreeMatrix(&m2);
    FreeMatrix(&m1);
    fprintf(stderr, "Resources freed, no errors occured!\n");
    return 0;
}

// Returns the read number or -1
int GetInputInt(void) {
    printf("\n");
    printf("\033[104;30m Select a function \033[0m\n");
    printf("1. Transpose M1\n");
    printf("2. Calculate M1 x M2\n");
    printf("3. Calculate M2 x M1\n");
    printf("4. Calculate M1 row-total\n");
    printf("5. Calculate M1 column-total\n");
    printf("0. Exit\n");
    printf("> ");
    int selection = -1;
    int scanReturn = 0;
    scanReturn = scanf(" %d", &selection);
    printf("\n");
    char c;
    do
        c = getchar();
    while (c != '\n' && c != EOF);  // Buffer flush
    if (scanReturn != 1)
        return -1;
    return selection;
}

// Allocates memory for a matrix
Matrix AllocMatrix(const unsigned int width, const unsigned int height) {
    Matrix newMatrix = (Matrix){{width, height}, NULL};
    newMatrix.items = calloc(width * height, sizeof(float));
    return newMatrix;
}

// Sets a specific matrix element to value
static inline void SetMatrix(Matrix* const matrix,
                             const unsigned int row,
                             const unsigned int column,
                             const float newValue) {
    matrix->items[column + row * matrix->size.x] = newValue;
}

// Gets a specific matrix element
static inline float GetMatrix(const Matrix* matrix, const unsigned int row, const unsigned int column) {
    return matrix->items[column + row * matrix->size.x];
}

// Fills a matrix with random data
void RandomFillMatrix(Matrix* const matrix, const unsigned int seed) {
    srand(seed);
    rand();
    const unsigned int w = matrix->size.x;
    const unsigned int h = matrix->size.y;
    for (size_t x = 0; x < w; x++) {
        for (size_t y = 0; y < h; y++) {
            SetMatrix(matrix, x, y, GetRandomFloat() * 10 - 5);
        }
    }
}

// Gets a random float between 0 and 1
static inline float GetRandomFloat() {
    return (float)rand() / RAND_MAX;
}

// Prints a preview of the matrix
void PreviewMatrix(const Matrix matrix) {
    for (size_t y = 0; y < min(3, matrix.size.y); y++) {
        fprintf(stderr, "│ ");
        for (size_t x = 0; x < min(3, matrix.size.x); x++) {
            fprintf(stderr, "%8.3f ", GetMatrix(&matrix, y, x));
        }
        if (matrix.size.x > 3)
            fprintf(stderr, "... ");
        fprintf(stderr, "│\n");
    }
    if (matrix.size.y > 3) {
        fprintf(stderr, "│      ...");
        switch (matrix.size.x) {
            default:
            case 4:
                fprintf(stderr, "      ...");
                fallthrough;
            case 3:
                fprintf(stderr, "      ...");
                fallthrough;
            case 2:
                fprintf(stderr, " ...");
                break;
            case 1:
                break;
        }
        fprintf(stderr, " │\n");
    }
}

// Frees memory for matrix
void FreeMatrix(Matrix* const matrix) {
    free(matrix->items);
}

// Perform a specific matrix operation
void MatrixCalc(const enum MatrixCalcOp op, struct ClContainer* cl, const Matrix m1, const Matrix m2) {
    enum UtilErr err;
    cl_int clErr;
    bool shouldLoadMat2 = false;

    // Load correct kernel
    {
        switch (op) {
            case MXCLOP_TRANSPOSE:
                err = LoadClContainerKernel(cl, "./matrix.cl", "TransposeMatrix");
                break;
            case MXCLOP_MULTIPLY:
                err = LoadClContainerKernel(cl, "./matrix.cl", "MultiplyMatrix");
                shouldLoadMat2 = true;
                break;
            case MXCLOP_ROWSUM:
                err = LoadClContainerKernel(cl, "./matrix.cl", "RowSumMatrix");
                break;
            case MXCLOP_COLSUM:
                err = LoadClContainerKernel(cl, "./matrix.cl", "ColSumMatrix");
                break;
            default:
                return;
        }
        if (err != UERR_NONE) {
            // Errmsg comes from LoadClContainerKernel
            return;
        }
    }

    // Sets up matrix 1
    {
        const size_t m1ByteSize = m1.size.x * m1.size.y * sizeof(m1.items[0]);
        // Buffer
        cl_mem m1cl =
            clCreateBuffer(cl->context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, m1ByteSize, m1.items, &clErr);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not load 1st matrix", clErr);
            return;
        }
        // Args (array)
        clErr = clSetKernelArg(cl->kernel, 1, sizeof(m1cl), (void*)&m1cl);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not set 2nd arg", clErr);
            return;
        }
        // Args (size)
        cl_uint2 m1size;
        m1size.x = m1.size.x;
        m1size.y = m1.size.y;
        clErr = clSetKernelArg(cl->kernel, 2, sizeof(m1size), (void*)&m1size);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not set 3rd arg", clErr);
            return;
        }
    }

    // Sets up matrix 2 if needed
    if (shouldLoadMat2) {
        const size_t m2ByteSize = m2.size.x * m2.size.y * sizeof(m2.items[0]);
        // Buffer
        cl_mem m2cl =
            clCreateBuffer(cl->context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, m2ByteSize, m2.items, &clErr);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not load 2nd matrix", clErr);
            return;
        }
        // Args (array)
        clErr = clSetKernelArg(cl->kernel, 3, sizeof(m2cl), (void*)&m2cl);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not set 4th arg", clErr);
            return;
        }
        // Args (size)
        cl_uint2 m2size;
        m2size.x = m2.size.x;
        m2size.y = m2.size.y;
        clErr = clSetKernelArg(cl->kernel, 4, sizeof(m2size), (void*)&m2size);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not set 5th arg", clErr);
            return;
        }
    }

    // Sets up result matrix
    Matrix mr;
    cl_mem mrcl;
    {
        // Size calc
        size_t mrByteSize = 0;
        switch (op) {
            case MXCLOP_TRANSPOSE:
                mr = AllocMatrix(m1.size.y, m1.size.x);
                break;
            case MXCLOP_MULTIPLY:
                mr = AllocMatrix(m2.size.x, m1.size.y);
                break;
            case MXCLOP_ROWSUM:
                mr = AllocMatrix(1, m1.size.y);
                break;
            case MXCLOP_COLSUM:
                mr = AllocMatrix(m1.size.x, 1);
                break;
            default:
                return;
        }
        mrByteSize = mr.size.x * mr.size.y * sizeof(mr.items[0]);
        // Buffer
        mrcl = clCreateBuffer(cl->context, CL_MEM_WRITE_ONLY, mrByteSize, NULL, &clErr);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not create result matrix", clErr);
            goto errReturn;
        }
        // Arg
        clErr = clSetKernelArg(cl->kernel, 0, sizeof(mrcl), (void*)&mrcl);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Could not set 1st arg", clErr);
            goto errReturn;
        }
    }

    // Calculation & data return
    {
        size_t mrByteSize = mr.size.x * mr.size.y * sizeof(mr.items[0]);
        const size_t totalSize = mrByteSize / sizeof(mr.items[0]);
        const size_t workSize = min(256, totalSize);
        clErr = clEnqueueNDRangeKernel(cl->queue, cl->kernel, 1, NULL, &totalSize, &workSize, 0, NULL, NULL);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Failed to execute kernel", clErr);
            goto errReturn;
        }

        clErr = clEnqueueReadBuffer(cl->queue, mrcl, CL_TRUE, 0, mrByteSize, (void*)mr.items, 0, NULL, NULL);
        if (clErr != CL_SUCCESS) {
            PrintClErr("Failed to read from device", clErr);
            goto errReturn;
        }
    }

    // Printing result
    fprintf(stderr, "Matrix result (Size: %ux%u):\n", mr.size.x, mr.size.y);
    PreviewMatrix(mr);

    // CPU Side verification
    switch (op) {
        case MXCLOP_TRANSPOSE:
            if (!VerifyTranspose(&m1, &mr))
                goto errReturn;
            break;
        case MXCLOP_MULTIPLY:
            if (!VerifyMultiply(&m1, &m2, &mr))
                goto errReturn;
            break;
        case MXCLOP_ROWSUM:
            if (!VerifyRowSum(&m1, &mr))
                goto errReturn;
            break;
        case MXCLOP_COLSUM:
            if (!VerifyColSum(&m1, &mr))
                goto errReturn;
            break;
    }
    fprintf(stdout, "\033[92mCPU-side verification succeeded!\033[0m\n");

// Free
errReturn:
    FreeMatrix(&mr);
}

// Returns `true` if the verification succeeded
static bool VerifyTranspose(const Matrix* m1, const Matrix* mr) {
    for (size_t c = 0; c < m1->size.x; c++) {
        for (size_t r = 0; r < m1->size.y; r++) {
            if (GetMatrix(m1, r, c) != GetMatrix(mr, c, r)) {
                fprintf(stdout, "\033[91mTranspose is incorrect! (m1[%llu,%llu]->%f != mr[%llu,%llu]->%f)\033[0m\n", r,
                        c, GetMatrix(m1, r, c), c, r, GetMatrix(mr, c, r));
                return false;
            }
        }
    }
    return true;
}

// Returns `true` if the verification succeeded
static bool VerifyMultiply(const Matrix* m1, const Matrix* m2, const Matrix* mr) {
    for (size_t c = 0; c < mr->size.x; c++) {
        for (size_t r = 0; r < mr->size.y; r++) {
            float total = 0.0f;
            for (size_t i = 0; i < m1->size.x; i++) {
                total += GetMatrix(m1, r, i) * GetMatrix(m2, i, c);
            }
            const float delta = total - GetMatrix(mr, r, c);
            if (delta > F32_EPSYLON || delta < -F32_EPSYLON) {
                fprintf(stdout, "\033[91mMultiply is incorrect! (mr[%llu,%llu]->%f != %f, diff: %f)\033[0m\n", r, c,
                        GetMatrix(mr, r, c), total, fabsf(GetMatrix(mr, r, c) - total));
                return false;
            }
        }
    }
    return true;
}

// Returns `true` if the verification succeeded
static bool VerifyRowSum(const Matrix* m1, const Matrix* mr) {
    for (size_t r = 0; r < m1->size.y; r++) {
        float sum = 0.0f;
        for (size_t c = 0; c < m1->size.x; c++) {
            sum += GetMatrix(m1, r, c);
        }
        if (sum != GetMatrix(mr, r, 0)) {
            fprintf(stdout, "\033[91mRow sum is incorrect! (mr[%llu,0]->%f != %f, diff: %f)\033[0m\n", r,
                    GetMatrix(mr, r, 0), sum, fabsf(GetMatrix(mr, r, 0) - sum));
            return false;
        }
    }
    return true;
}

// Returns `true` if the verification succeeded
static bool VerifyColSum(const Matrix* m1, const Matrix* mr) {
    for (size_t c = 0; c < m1->size.x; c++) {
        float sum = 0.0f;
        for (size_t r = 0; r < m1->size.y; r++) {
            sum += GetMatrix(m1, r, c);
        }
        if (sum != GetMatrix(mr, 0, c)) {
            fprintf(stdout, "\033[91mColumn sum is incorrect! (mr[0,%llu]->%f != %f, diff: %f)\033[0m\n", c,
                    GetMatrix(mr, 0, c), sum, fabsf(GetMatrix(mr, 0, c) - sum));
            return false;
        }
    }
    return true;
}
