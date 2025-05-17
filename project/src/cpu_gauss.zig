const std = @import("std");

const ALIGNMENT = 3;

fn gaussian(x: f32, y: f32, sigma: f32) f32 {
    const pi = std.math.pi;
    const exponent = -(x * x + y * y) / (2 * sigma * sigma);
    return 1 / (2 * pi * sigma * sigma) * std.math.exp(exponent);
}

fn getColor(src: []const u8, x: i64, y: i64, width: u64) [3]u8 {
    const i: usize = @intCast((y * @as(i64, @intCast(width)) + x) * ALIGNMENT);
    return .{ src[i + 0], src[i + 1], src[i + 2] };
}

pub fn gaussianBlur(a: std.mem.Allocator, src: []const u8, width: u64, height: u64, kernel_size: u16) ![]u8 {
    const sigma: f32 = @as(f32, @floatFromInt(kernel_size)) / 6.0;
    const dk: i32 = @divTrunc((@as(i32, kernel_size) - 1), 2);
    var dst = try a.alloc(u8, src.len);

    for (0..width) |x| {
        for (0..height) |y| {
            const pxl = gaussPixel(src, width, height, @intCast(x), @intCast(y), dk, sigma, kernel_size);
            dst[(x + width * y) * ALIGNMENT] = pxl[0];
            dst[(x + width * y) * ALIGNMENT + 1] = pxl[1];
            dst[(x + width * y) * ALIGNMENT + 2] = pxl[2];
        }
    }
    return dst;
}

fn gaussPixel(src: []const u8, width: u64, height: u64, x: i64, y: i64, dk: i32, sigma: f32, kernel_size: u16) [3]u8 {
    var new_color: [3]f32 = .{ 0.0, 0.0, 0.0 };
    var n: f32 = 0.0;

    for (0..kernel_size) |dxs| {
        const dx: i64 = @as(i64, @intCast(dxs)) - dk;
        for (0..kernel_size) |dys| {
            const dy: i64 = @as(i64, @intCast(dys)) - dk;
            if (x + dx >= 0 and x + dx < width and y + dy >= 0 and y + dy < height) {
                const color: [3]u8 = getColor(src, x + dx, y + dy, width);
                const weight: f32 = gaussian(@floatFromInt(dx), @floatFromInt(dy), sigma);
                new_color[0] += @as(f32, @floatFromInt(color[0])) * weight;
                new_color[1] += @as(f32, @floatFromInt(color[1])) * weight;
                new_color[2] += @as(f32, @floatFromInt(color[2])) * weight;
                n += weight;
            }
        }
    }

    var res: [3]u8 = .{ 0, 0, 0 };
    res[0] = @as(u8, @intFromFloat(new_color[0] / n));
    res[1] = @as(u8, @intFromFloat(new_color[1] / n));
    res[2] = @as(u8, @intFromFloat(new_color[2] / n));
    return res;
}
