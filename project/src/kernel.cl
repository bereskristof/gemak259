__kernel void gaussBlur(__read_only image2d_t image, uint k) {
    uint x = get_global_id(0);
    uint y = get_global_id(1);
    uint width = get_image_width(image);
    uint height = get_image_height(image);
    if (x >= width || y >= height)
        return;
}
