const std = @import("std");
const cl = @import("cl_binding.zig");
const Image = @import("netpbm.zig");
const args = @import("argparse.zig");
const buildConfig = @import("build_config");

const exit_success = 0;
const exit_failure = 1;
const exit_complete_failure = 2;
const help_text = @embedFile("help_text.txt");
const name = buildConfig.name;
const version = buildConfig.version;

pub fn main() u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    var run_config = args.Properties.init(allocator) catch |err| switch (err) {
        args.ArgError.ConflictingInputs => return errorExit("Error: '-i' and 'FILE...' are mutually exclusive!\n"),
        args.ArgError.AllocationError => return errorExit("Error: Failed to allocate memory!\n"),
        args.ArgError.InvalidInput => return errorExit("Error: Argument option is an invalid value!\n"),
        args.ArgError.UnknownArgument => return errorExit("Error: Unknown argument!\n"),
    };
    defer run_config.deinit();

    switch (run_config.tool) {
        .Default, .Help => stdout.print(help_text, .{name}) catch return exit_complete_failure,
        else => _ = stdout.write("Todo") catch return exit_complete_failure,
    }

    return exit_success;
}

fn errorExit(comptime msg: []const u8) u8 {
    const stderr = std.io.getStdErr().writer();
    _ = stderr.write(msg) catch {
        return exit_complete_failure;
    };
    return exit_failure;
}
