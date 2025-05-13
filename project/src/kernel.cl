// Sets the kernel size, applied at compile time
#ifndef KERNEL_SIZE
#define KERNEL_SIZE (5)
#endif

// We use `uchar *image` instead of `uchar3 *image` due to `uchar3` being aligned to 4 bytes
__constant uint ALIGNMENT = 3;

uchar3 getColor(__global uchar *image, uint x, uint y, uint width) {
    uint i = (y * width + x) * ALIGNMENT;
    return (uchar3)(image[i], image[i + 1], image[i + 2]);
}

float gaussian(float x, float y, float sigma) {
    return exp(-(x * x + y * y) / (2 * sigma * sigma)) / (2 * M_PI * sigma * sigma);
}

float clampf(float value, float min, float max) {
    return fmax(fmin(value, max), min);
}

// Unused due to noticeable performance drop (Gauss k=91 -> 2.1s vs 3.3s)
// void convolutionEffect(__global uchar *src,
//                        __global uchar *dst,
//                        uint width,
//                        uint height,
//                        float convolution[KERNEL_SIZE * KERNEL_SIZE]) {
//     uint x = get_global_id(0);
//     uint y = get_global_id(1);
//     uint i = (y * width + x) * ALIGNMENT;
//     if (x >= width || y >= height) {
//         return;
//     }

//     const int dk = (KERNEL_SIZE - 1) / 2;
//     float3 new_color = (float3)(0, 0, 0);
//     float n = 0;
//     for (int dy = -dk; dy <= dk; dy++) {
//         for (int dx = -dk; dx <= dk; dx++) {
//             if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
//                 const uchar3 color = getColor(src, x + dx, y + dy, width);
//                 const float weight = convolution[((dy + dk) * KERNEL_SIZE) + (dx + dk)];
//                 new_color.x += (float)(color.x) * weight;
//                 new_color.y += (float)(color.y) * weight;
//                 new_color.z += (float)(color.z) * weight;
//                 n += weight;
//             }
//         }
//     }

//     dst[i + 0] = (uchar)((ulong)(new_color.x / n) % 256);
//     dst[i + 1] = (uchar)((ulong)(new_color.y / n) % 256);
//     dst[i + 2] = (uchar)((ulong)(new_color.z / n) % 256);
// }

__kernel void edgeMask(__global uchar *src, __global uchar *dst, uint width, uint height, float delta) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }

    const int dk = (KERNEL_SIZE - 1) / 2;
    float3 new_color = (float3)(0, 0, 0);
    float2 offsets[4] = {(float2)(-dk, 0), (float2)(dk, 0), (float2)(0, -dk), (float2)(0, dk)};
    float n = 0;
    for (int i = 0; i < 4; i++) {
        const float2 offset = offsets[i];
        if (x + offset.x >= 0 && x + offset.x < width && y + offset.y >= 0 && y + offset.y < height) {
            const uchar3 color = getColor(src, x + offset.x, y + offset.y, width);
            new_color.x -= (float)(color.x);
            new_color.y -= (float)(color.y);
            new_color.z -= (float)(color.z);
            n += 1;
        }
    }
    const uchar3 color = getColor(src, x, y, width);
    new_color.x += (float)(color.x) * (n + delta);
    new_color.y += (float)(color.y) * (n + delta);
    new_color.z += (float)(color.z) * (n + delta);

    dst[i + 0] = (uchar)(clampf(new_color.x, 0, 255));
    dst[i + 1] = (uchar)(clampf(new_color.y, 0, 255));
    dst[i + 2] = (uchar)(clampf(new_color.z, 0, 255));
}

__kernel void sharpenMask(__global uchar *src, __global uchar *dst, uint width, uint height) {
    edgeMask(src, dst, width, height, 1);
}

__kernel void ridgeMask(__global uchar *src, __global uchar *dst, uint width, uint height) {
    edgeMask(src, dst, width, height, 0);
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

    const float sigma = (float)(KERNEL_SIZE) / 6;
    const int dk = (KERNEL_SIZE - 1) / 2;
    float3 new_color = (float3)(0, 0, 0);
    float n = 0;
    for (int dy = -dk; dy <= dk; dy++) {
        for (int dx = -dk; dx <= dk; dx++) {
            if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
                const uchar3 color = getColor(src, x + dx, y + dy, width);
                const float weight = gaussian((float)(dx), (float)(dy), sigma);
                new_color.x += (float)(color.x) * weight;
                new_color.y += (float)(color.y) * weight;
                new_color.z += (float)(color.z) * weight;
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

    const float sigma = (float)(KERNEL_SIZE) / 6;
    const int dk = (KERNEL_SIZE - 1) / 2;
    float3 new_color = (float3)(0, 0, 0);
    float n = 0;
    for (int dy = -dk; dy <= dk; dy++) {
        for (int dx = -dk; dx <= dk; dx++) {
            if (x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height) {
                const uchar3 color = getColor(src, x + dx, y + dy, width);
                const float weight = gaussian((float)(dx), (float)(dy), sigma);
                new_color.x += (float)(color.x) * weight;
                new_color.y += (float)(color.y) * weight;
                new_color.z += (float)(color.z) * weight;
                n += weight;
            }
        }
    }
    const uchar3 color = getColor(src, x, y, width);
    new_color.x += (float)(color.x) * 2;
    new_color.y += (float)(color.y) * 2;
    new_color.z += (float)(color.z) * 2;
    n += 2;

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
        uchar minValue = MAX(colors[j].x, colors[j].y, colors[j].z);
        for (int k = j + 1; k < n; k++) {
            uchar value = MAX(colors[k].x, colors[k].y, colors[k].z);
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
