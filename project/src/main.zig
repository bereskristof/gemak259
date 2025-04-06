const std = @import("std");
const cl = @import("cl_binding.zig");
const Image = @import("netpbm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const image = try Image.init(allocator, @embedFile("test.ppm"));

    image.print() catch {};

    // const platforms = try cl.getPlatformIds(allocator);
    // defer allocator.free(platforms);
    // if (platforms.len < 1) return;
    // std.debug.print("Platform count: {d}\n", .{platforms.len});

    // const devices = try cl.getDeviceIds(allocator, platforms[0]);
    // defer allocator.free(devices);
    // defer devices[0].release();
    // std.debug.print("Device count: {d}\n", .{devices.len});

    // const context = try cl.createContext(devices);
    // defer context.release();

    // const queue = try cl.createCommandQueue(context, devices[0]);
    // defer queue.release();

    // std.debug.print("No errors occurred!\n", .{});
}
