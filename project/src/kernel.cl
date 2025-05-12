// We use `uchar *image` instead of `uchar3 *image` due to it being aligned to 4 bytes
const uint ALIGNMENT = 3;

uchar3 getColor(uchar *image, uint x, uint y, uint width) {
    uint i = (y * width + x) * ALIGNMENT;
    return (uchar3)(image[i], image[i + 1], image[i + 2]);
}

__kernel void boxBlur(__global uchar *src, __global uchar *dst, uint k, uint width, uint height) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }

    const int dk = ((int)(k)-1) / 2;
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
