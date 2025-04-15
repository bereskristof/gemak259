const std = @import("std");
const cl = @import("cl_binding.zig");
const args = @import("argparse.zig");
const build_config = @import("build_config");

const Image = @import("netpbm.zig");

const exit_success = 0;
const exit_failure = 1;
const exit_complete_failure = 2;
const help_text = @embedFile("help_text.txt");
const name = build_config.name;
const version = build_config.version;

// Used when a fatal error occured, and the user was already notified about the error.
// TODO: This breaks silent
const HandledError = error{
    Fatal,
    FatalMessageFailed,
};

pub fn main() u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    // TODO: Move OpenCL init to where it should be
    const platforms = clGetPlatforms(allocator) catch |err| return getFatalErrorValue(err);
    defer allocator.free(platforms);

    const devices = clGetDevices(allocator, platforms) catch |err| return getFatalErrorValue(err);
    defer allocator.free(devices); // TODO: Make this better
    defer for (devices) |device| device.release();

    const context = clGetContext(devices) catch |err| return getFatalErrorValue(err);
    defer context.release();

    const queue = clGetCommandQueue(context, devices[0]) catch |err| return getFatalErrorValue(err); // TODO: Check for best device
    _ = queue;

    var run_config = getRunConfig(allocator) catch |err| return getFatalErrorValue(err);
    defer run_config.deinit();

    switch (run_config.tool) {
        .Default, .Help => stdout.print(help_text, .{name}) catch return exit_complete_failure,
        .Version => stdout.print("{s}\n", .{version}) catch return exit_complete_failure,
        else => _ = handleInputs(allocator, run_config) catch |err| return getFatalErrorValue(err),
    }

    return exit_success;
}

fn clGetPlatforms(a: std.mem.Allocator) HandledError![]const cl.PlatformId {
    const platforms = cl.getPlatformIds(a) catch |err| switch (err) {
        cl.ClError.PlatformNotFound => return printAndReturnError("Error: OpenCL platform not found!\n"),
        cl.ClError.OutOfMemory => return printAndReturnError("Error: OpenCL out of memory!\n"),
        else => return printAndReturnError("Error: OpenCL failed to get platforms!\n"),
    };
    errdefer a.free(platforms);
    if (platforms.len < 1) {
        return printAndReturnError("Error: No OpenCL platform found!\n");
    }
    return platforms;
}

fn clGetDevices(a: std.mem.Allocator, platforms: []const cl.PlatformId) HandledError![]const cl.DeviceId {
    const devices = cl.getDeviceIds(a, platforms[0]) catch |err| switch (err) {
        cl.ClError.InvalidPlatform => return printAndReturnError("Error: OpenCL platform is invalid!\n"),
        cl.ClError.DeviceNotFound => return printAndReturnError("Error: OpenCL device not found!\n"),
        cl.ClError.OutOfResources => return printAndReturnError("Error: OpenCL resources unavailable!\n"),
        cl.ClError.OutOfMemory => return printAndReturnError("Error: OpenCL out of memory!\n"),
        else => return printAndReturnError("Error: OpenCL failed to get devices!\n"),
    };
    errdefer a.free(devices); // TODO: Make this better
    errdefer for (devices) |device| device.release();
    if (devices.len < 1) {
        return printAndReturnError("Error: No OpenCL device found!\n");
    }
    return devices;
}

fn clGetContext(devices: []const cl.DeviceId) HandledError!cl.Context {
    return cl.createContext(devices) catch |err| switch (err) {
        cl.ClError.InvalidValue => return printAndReturnError("Error: OpenCL value is invalid!\n"),
        cl.ClError.DeviceNotAvailable => return printAndReturnError("Error: OpenCL devices are unavailable!\n"),
        cl.ClError.OutOfResources => return printAndReturnError("Error: OpenCL resources unavailable!\n"),
        cl.ClError.OutOfMemory => return printAndReturnError("Error: OpenCL out of memory!\n"),
        else => return printAndReturnError("Error: OpenCL failed to create context!\n"),
    };
}

fn clGetCommandQueue(context: cl.Context, device: cl.DeviceId) HandledError!cl.CommandQueue {
    return cl.createCommandQueue(context, device) catch |err| switch (err) {
        cl.ClError.OutOfResources => return printAndReturnError("Error: OpenCL out of resources!\n"),
        cl.ClError.OutOfMemory => return printAndReturnError("Error: OpenCL out of memory!\n"),
        cl.ClError.InvalidContext => return printAndReturnError("Error: OpenCL the context is invalid!\n"),
        cl.ClError.InvalidDevice => return printAndReturnError("Error: OpenCL the device is invalid!\n"),
        cl.ClError.InvalidValue => return printAndReturnError("Error: OpenCL the value is invalid!\n"),
        else => return printAndReturnError("Error: Failed to create OpenCL command queue!\n"),
    };
}

fn getRunConfig(a: std.mem.Allocator) HandledError!args.Properties {
    return args.Properties.init(a) catch |err| switch (err) {
        args.ArgError.ConflictingInputs => return printAndReturnError("Error: '-i' and 'FILE...' are mutually exclusive!\n"),
        args.ArgError.AllocationError => return printAndReturnError("Error: Failed to allocate memory!\n"),
        args.ArgError.InvalidInput => return printAndReturnError("Error: Argument option is an invalid value!\n"),
        args.ArgError.UnknownArgument => return printAndReturnError("Error: Unknown argument!\n"),
    };
}

fn handleInputs(a: std.mem.Allocator, properties: args.Properties) HandledError!void {
    return switch (properties.source) {
        .files => handleFiles(a, properties),
        .stdin => handleStdin(a, properties.silent),
        .none => printAndReturnError("Error: No source files provided!\n"),
    };
}

fn handleStdin(a: std.mem.Allocator, silent: bool) HandledError!void {
    const stdin = std.io.getStdIn().reader();
    const data = stdin.readAllAlloc(a, 1 << 30) catch |err| switch (err) {
        error.StreamTooLong => return printAndReturnError("Error: File exceeds maximum file size (1 GiB)\n"),
        error.OutOfMemory => return printAndReturnError("Error: Out of memory!\n"),
        else => return printAndReturnError("Error: Could not read input from file!\n"),
    };
    defer a.free(data);

    handleData(a, data) catch |err| if (!silent) return err;
}

fn handleFiles(a: std.mem.Allocator, properties: args.Properties) HandledError!void {
    var i: usize = 0;
    while (properties.getFile(i)) |file_name| : (i += 1) {
        handleFile(a, file_name) catch |err| if (!properties.silent) return err;
    }
}

fn handleFile(a: std.mem.Allocator, file_name: []const u8) HandledError!void {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(file_name, .{}) catch |err| switch (err) {
        error.FileNotFound => return printAndReturnError("Error: File not found!\n"),
        error.AccessDenied => return printAndReturnError("Error: Access to file is denied!\n"),
        else => return printAndReturnError("Error: Unknown file access error!\n"), // TODO: Add more of these, since they are no longer bubbled to the top
    };
    defer file.close();

    const file_data = file.readToEndAlloc(a, 1 << 30) catch |err| switch (err) {
        error.FileTooBig => return printAndReturnError("Error: File exceeds maximum file size (1 GiB)\n"),
        error.OutOfMemory => return printAndReturnError("Error: Out of memory!\n"),
        else => return printAndReturnError("Error: Could not read input from file!\n"),
    };
    defer a.free(file_data);
    try handleData(a, file_data);
}

fn handleData(a: std.mem.Allocator, file_data: []const u8) HandledError!void {
    var image = Image.init(a, file_data) catch |err| switch (err) {
        error.Unsupported => return printAndReturnError("Error: NetPBM type is not supported!\n"),
        error.WrongMagicNumber => return printAndReturnError("Error: File type is not supported!\n"),
        error.CorruptedHeaderData => return printAndReturnError("Error: Could not read header!\n"),
        error.OutOfMemory => return printAndReturnError("Error: Memory allocation failed!\n"),
        error.UnreadableString => return printAndReturnError("Error: File data portion is corrupted!\n"),
        error.DamagedData => return printAndReturnError("Error: File data portion is corrupted!\n"),
    };
    defer image.deinit();

    image.print() catch {}; // TODO: Replace with actual handling!
}

fn getFatalErrorValue(err: HandledError) u8 {
    return switch (err) {
        HandledError.Fatal => 1,
        HandledError.FatalMessageFailed => 2,
    };
}

fn printAndReturnError(comptime msg: []const u8) HandledError {
    const stderr = std.io.getStdErr().writer();
    _ = stderr.write(msg) catch {
        return HandledError.FatalMessageFailed;
    };
    return HandledError.Fatal;
}
