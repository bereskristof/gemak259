// Sets the kernel size, applied at compile time
#ifndef KERNEL_SIZE
#define KERNEL_SIZE (5)
#endif

// We use `uchar *image` instead of `uchar3 *image` due to `uchar3` being aligned to 4 bytes
const uint ALIGNMENT = 3;

uchar3 getColor(uchar *image, uint x, uint y, uint width) {
    uint i = (y * width + x) * ALIGNMENT;
    return (uchar3)(image[i], image[i + 1], image[i + 2]);
}

double gaussian(double x, double y, double sigma) {
    return exp(-(x * x + y * y) / (2 * sigma * sigma)) / (2 * M_PI * sigma * sigma);
}

// Unused due to noticeable performance drop (Gauss k=91 -> 2.1s vs 3.3s)
// void convolutionEffect(__global uchar *src,
//                        __global uchar *dst,
//                        uint width,
//                        uint height,
//                        double convolution[KERNEL_SIZE * KERNEL_SIZE]) {
//     uint x = get_global_id(0);
//     uint y = get_global_id(1);
//     uint i = (y * width + x) * ALIGNMENT;
//     if (x >= width || y >= height) {
//         return;
//     }

//     const int dk = (KERNEL_SIZE - 1) / 2;
//     double3 new_color = (double3)(0.0, 0.0, 0.0);
//     double n = 0.0;
//     for (int dy = -dk; dy <= dk; dy++) {
//         for (int dx = -dk; dx <= dk; dx++) {
//             if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
//                 const uchar3 color = getColor(src, x + dx, y + dy, width);
//                 const double weight = convolution[((dy + dk) * KERNEL_SIZE) + (dx + dk)];
//                 new_color.x += (double)(color.x) * weight;
//                 new_color.y += (double)(color.y) * weight;
//                 new_color.z += (double)(color.z) * weight;
//                 n += weight;
//             }
//         }
//     }

//     dst[i + 0] = (uchar)((ulong)(new_color.x / n) % 256);
//     dst[i + 1] = (uchar)((ulong)(new_color.y / n) % 256);
//     dst[i + 2] = (uchar)((ulong)(new_color.z / n) % 256);
// }

__kernel void edgeMask(__global uchar *src, __global uchar *dst, uint width, uint height, double delta) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }

    const int dk = (KERNEL_SIZE - 1) / 2;
    double3 new_color = (double3)(0.0, 0.0, 0.0);
    double2 offsets[4] = {(double2)(-dk, 0.0), (double2)(dk, 0.0), (double2)(0.0, -dk), (double2)(0.0, dk)};
    double n = 0.0;
    for (int i = 0; i < 4; i++) {
        const double2 offset = offsets[i];
        if (x + offset.x >= 0 && x + offset.x < width && y + offset.y >= 0 && y + offset.y < height) {
            const uchar3 color = getColor(src, x + offset.x, y + offset.y, width);
            new_color.x -= (double)(color.x);
            new_color.y -= (double)(color.y);
            new_color.z -= (double)(color.z);
            n += 1.0;
        }
    }
    const uchar3 color = getColor(src, x, y, width);
    new_color.x += (double)(color.x) * (n + delta);
    new_color.y += (double)(color.y) * (n + delta);
    new_color.z += (double)(color.z) * (n + delta);

    dst[i + 0] = (uchar)(clamp(new_color.x, 0.0, 255.0));
    dst[i + 1] = (uchar)(clamp(new_color.y, 0.0, 255.0));
    dst[i + 2] = (uchar)(clamp(new_color.z, 0.0, 255.0));
}

__kernel void sharpenMask(__global uchar *src, __global uchar *dst, uint width, uint height) {
    edgeMask(src, dst, width, height, 1.0);
}

__kernel void ridgeMask(__global uchar *src, __global uchar *dst, uint width, uint height) {
    edgeMask(src, dst, width, height, 0.0);
}

__kernel void boxBlur(__global uchar *src, __global uchar *dst, uint width, uint height) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }

    const int dk = ((int)(KERNEL_SIZE)-1) / 2;
    ulong3 new_color = (ulong3)(0, 0, 0);
    ulong n = 0;
    for (int dy = -dk; dy <= dk; dy++) {
        for (int dx = -dk; dx <= dk; dx++) {
            if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
                const uchar3 color = getColor(src, x + dx, y + dy, width);
                new_color.x += (ulong)(color.x);
                new_color.y += (ulong)(color.y);
                new_color.z += (ulong)(color.z);
                n += 1;
            }
        }
    }
    dst[i + 0] = (uchar)((new_color.x / n) % 256);
    dst[i + 1] = (uchar)((new_color.y / n) % 256);
    dst[i + 2] = (uchar)((new_color.z / n) % 256);
}

__kernel void gaussianBlur(__global uchar *src, __global uchar *dst, uint width, uint height) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }

    const double sigma = (double)(KERNEL_SIZE) / 6.0;
    const int dk = (KERNEL_SIZE - 1) / 2;
    double3 new_color = (double3)(0.0, 0.0, 0.0);
    double n = 0.0;
    for (int dy = -dk; dy <= dk; dy++) {
        for (int dx = -dk; dx <= dk; dx++) {
            if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
                const uchar3 color = getColor(src, x + dx, y + dy, width);
                const double weight = gaussian((double)(dx), (double)(dy), sigma);
                new_color.x += (double)(color.x) * weight;
                new_color.y += (double)(color.y) * weight;
                new_color.z += (double)(color.z) * weight;
                n += weight;
            }
        }
    }

    dst[i + 0] = (uchar)((ulong)(new_color.x / n) % 256);
    dst[i + 1] = (uchar)((ulong)(new_color.y / n) % 256);
    dst[i + 2] = (uchar)((ulong)(new_color.z / n) % 256);
}

__kernel void unsharpMask(__global uchar *src, __global uchar *dst, uint width, uint height) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }

    const double sigma = (double)(KERNEL_SIZE) / 6.0;
    const int dk = (KERNEL_SIZE - 1) / 2;
    double3 new_color = (double3)(0.0, 0.0, 0.0);
    double n = 0.0;
    for (int dy = -dk; dy <= dk; dy++) {
        for (int dx = -dk; dx <= dk; dx++) {
            if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
                const uchar3 color = getColor(src, x + dx, y + dy, width);
                const double weight = gaussian((double)(dx), (double)(dy), sigma);
                new_color.x += (double)(color.x) * weight;
                new_color.y += (double)(color.y) * weight;
                new_color.z += (double)(color.z) * weight;
                n += weight;
            }
        }
    }
    const uchar3 color = getColor(src, x, y, width);
    new_color.x += (double)(color.x) * 2.0;
    new_color.y += (double)(color.y) * 2.0;
    new_color.z += (double)(color.z) * 2.0;
    n += 2.0;

    dst[i + 0] = (uchar)((ulong)(new_color.x / n) % 256);
    dst[i + 1] = (uchar)((ulong)(new_color.y / n) % 256);
    dst[i + 2] = (uchar)((ulong)(new_color.z / n) % 256);
}

#define MAX(a, b, c) ((a) > (b) ? ((a) > (c) ? (a) : (c)) : ((b) > (c) ? (b) : (c)))

__kernel void medianMethod(__global uchar *src, __global uchar *dst, uint width, uint height) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }

    const int dk = (KERNEL_SIZE - 1) / 2;
    uchar3 colors[KERNEL_SIZE * KERNEL_SIZE];
    int n = 0;
    for (int dy = -dk; dy <= dk; dy++) {
        for (int dx = -dk; dx <= dk; dx++) {
            if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
                const uchar3 color = getColor(src, x + dx, y + dy, width);
                colors[n] = (uchar3)(color.x, color.y, color.z);
                n += 1;
            }
        }
    }

    for (int c = 0; c < KERNEL_SIZE * KERNEL_SIZE; c++) {
    }

    for (int j = 0; j < n - 1; j++) {
        uint min = j;
        uchar minValue = MAX(colors[j].r, colors[j].g, colors[j].b);
        for (int k = j + 1; k < n; k++) {
            uchar value = MAX(colors[k].r, colors[k].g, colors[k].b);
            if (value < minValue) {
                minValue = value;
                min = k;
            }
        }
        uchar3 temp = colors[j];
        colors[j] = colors[min];
        colors[min] = temp;
    }

    dst[i + 0] = (uchar)(colors[n / 2].x);
    dst[i + 1] = (uchar)(colors[n / 2].y);
    dst[i + 2] = (uchar)(colors[n / 2].z);
}
