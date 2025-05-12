// We use `uchar *image` instead of `uchar3 *image` due to it being aligned to 4 bytes
const uint ALIGNMENT = 3;

__kernel void gaussBlur(__global uchar *image, uint k, uint width, uint height) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint i = (y * width + x) * ALIGNMENT;
    if (x >= width || y >= height) {
        return;
    }
    uchar3 color = (uchar3)(image[i], image[i + 1], image[i + 2]);
    image[i] = 0;        // color.x;
    image[i + 1] = 128;  // color.y;
    image[i + 2] = 255;  // color.z;
}
