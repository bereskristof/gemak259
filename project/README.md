# Párhuzamos eszközök programozása beadandó

Egyszerű képmódosítási műveletekhez alkalmazható CLI program.

```
Performs basic image handling methods on netpbm images.
Currently supports ASCII (P3) and binary (P6) .ppm files.

Usage:
  ppmfltrcl (blur | gauss | median | ...) FILE...

Tools:
  blur     Blurs the image using box blur.
  sharpen  Applies a sharpness filter.
  ridge    Performs basic ridge detection.
  gauss    Blurs the image using gaussian blur.
  unsharp  Performs unsharp masking on the image.
  median   Perform median filtering on the image.
  gauss-cpu  Blurs the image using gaussian blur, using the cpu instead of
             the gpu.

Options:
  -h       Shows this screen.
  -v       Prints the programs version.
  -i       Reads the contents from stdin instead of FILEs.
  -o DIR   Specifies the output directory.
  -t       Print runtime information.
  -f       Continues skipping the file if some error occures.
  -k <px>  The size of the pixel kernel [default: 3]. <px> must be an odd
           positive value, between 1 and 255 (inclusive).
```

https://github.com/ziglang/zig/tree/0.14.0

## Futási idők (Gaussian blur)

Build flags: `> zig build -Doptimize=ReleaseFast -Dcpu=x86_64_v3`

### Tests 1

Hardware:
- **CPU:** AMD Ryzen 5 5500
- **GPU:** NVIDIA GeForce RTX 2060 (6GB)
- **RAM:** 2x8GB @ 3200 MT/s

| Command                                   | CPU total runtime (usec) | CPU calculation time (usec) | GPU total runtime (usec) | GPU calculation time (usec) | GPU OpenCL setup time (usec) | Total improvement |
| ----------------------------------------- | ------------------------ | --------------------------- | ------------------------ | --------------------------- | ---------------------------- | ----------------- |
| `ppmfltrcl gauss vd.ppm -tk5`             | 4 358 usec               | 2 532 usec                  | 152 811 usec             | 624 usec                    | 150 299 usec                 | 35 times worse    |
| `ppmfltrcl gauss vd.ppm -tk21`            | 39 623 usec              | 38 339 usec                 | 109 979 usec             | 1 662 usec                  | 106 687 usec                 | 2.8 times worse   |
| `ppmfltrcl gauss grid-gradient.ppm -tk21` | 162 665 usec             | 161 215 usec                | 100 273 usec             | 3 545 usec                  | 100 273 usec                 | 1.6 times better  |
| `ppmfltrcl gauss landscape.ppm -tk15`     | 5 411 603 usec           | 5 319 521 usec              | 221 684 usec             | 84 467 usec                 | 123 738 usec                 | 24 times better   |

### Tests 2

Hardware:
- **CPU:** Intel Core i5 1135G7
- **GPU:** Intel Iris Xe Graphics
- **RAM:** 8x1GB @ 4267 MT/s

| Command                                   | CPU total runtime (usec) | CPU calculation time (usec) | GPU total runtime (usec) | GPU calculation time (usec) | GPU OpenCL setup time (usec) | Total improvement |
| ----------------------------------------- | ------------------------ | --------------------------- | ------------------------ | --------------------------- | ---------------------------- | ----------------- |
| `ppmfltrcl gauss vd.ppm -tk5`             | 12 503 usec              | 9 936 usec                  | 1 484 505 usec           | 2 448 usec                  | 1 479 084 usec               | 119 times worse   |
| `ppmfltrcl gauss vd.ppm -tk21`            | 159 143 usec             | 155 763 usec                | 1 433 440 usec           | 2 807 usec                  | 1 427 252 usec               | 9 times worse     |
| `ppmfltrcl gauss grid-gradient.ppm -tk21` | 718 038 usec             | 732 953 usec                | 1 420 081 usec           | 3 324 usec                  | 1 412 557 usec               | 2 times worse     |
| `ppmfltrcl gauss landscape.ppm -tk15`     | 22 142 285 usec          | 22 085 500 usec             | 1 396 339 usec           | 37 666 usec                 | 1 327 069 usec               | 15 times better   |
