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
const cl_source: [:0]const u8 = @embedFile("kernel.cl");

// Used when a fatal error occured, and the user was already notified about the error.
const HandledError = error{
    Fatal,
    FatalMessageFailed,
};

const ClBundle = struct {
    platform: cl.PlatformId,
    device: cl.DeviceId,
    context: cl.Context,
    queue: cl.CommandQueue,
};

pub fn main() u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var run_config = getRunConfig(allocator) catch |err| return getFatalErrorValue(err);
    defer run_config.deinit();

    var complete_timer: ?std.time.Timer = if (run_config.timed) std.time.Timer.start() catch null else null;
    switch (run_config.tool) {
        .Default, .Help => stdout.print(help_text, .{name}) catch return exit_complete_failure,
        .Version => stdout.print("{s}\n", .{version}) catch return exit_complete_failure,
        else => _ = handleInputs(allocator, run_config) catch |err| return getFatalErrorValue(err),
    }
    if (complete_timer) |*timer| {
        const runtime = timer.read();
        stderr.print("Complete runtime: {d} ms\n", .{runtime / std.time.ns_per_ms}) catch {};
    }

    return exit_success;
}

fn clInit(a: std.mem.Allocator) HandledError!ClBundle {
    const platforms = try clGetPlatforms(a);
    defer a.free(platforms);
    const platform = platforms[0];

    const devices = try clGetDevices(a, platform);
    defer a.free(devices);
    defer for (devices, 0..) |array_device, i| if (i != 0) array_device.release();
    const device = devices[0];

    const context = try clGetContext(device);
    errdefer context.release();

    const queue = try clGetCommandQueue(context, device); // TODO: Check for best device

    return .{
        .platform = platform,
        .device = device,
        .context = context,
        .queue = queue,
    };
}

fn clFree(a: std.mem.Allocator, cl_bundle: ClBundle) void {
    _ = a;
    cl_bundle.device.release();
    cl_bundle.context.release();
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

fn clGetDevices(a: std.mem.Allocator, platform: cl.PlatformId) HandledError![]const cl.DeviceId {
    const devices = cl.getDeviceIds(a, platform) catch |err| switch (err) {
        cl.ClError.InvalidPlatform => return printAndReturnError("Error: OpenCL platform is invalid!\n"),
        cl.ClError.DeviceNotFound => return printAndReturnError("Error: OpenCL device not found!\n"),
        cl.ClError.OutOfResources => return printAndReturnError("Error: OpenCL resources unavailable!\n"),
        cl.ClError.OutOfMemory => return printAndReturnError("Error: OpenCL out of memory!\n"),
        else => return printAndReturnError("Error: OpenCL failed to get devices!\n"),
    };
    errdefer a.free(devices);
    errdefer for (devices) |device| device.release();
    if (devices.len < 1) {
        return printAndReturnError("Error: No OpenCL device found!\n");
    }
    return devices;
}

fn clGetContext(device: cl.DeviceId) HandledError!cl.Context {
    return cl.createContext(device) catch |err| switch (err) {
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

fn clGetProgram(context: cl.Context) HandledError!cl.Program {
    return cl.createProgramWithSource(context, cl_source) catch |err| switch (err) {
        cl.ClError.OutOfResources => return printAndReturnError("Error: OpenCL out of resources!\n"),
        cl.ClError.OutOfMemory => return printAndReturnError("Error: OpenCL out of memory!\n"),
        else => return printAndReturnError("Error: Failed to create OpenCL program!\n"),
    };
}

fn clGetKernel(program: cl.Program, kernel_name: [:0]const u8) HandledError!cl.Kernel {
    return cl.createKernel(program, kernel_name) catch |err| switch (err) {
        cl.ClError.OutOfResources => return printAndReturnError("Error: OpenCL out of resources!\n"),
        cl.ClError.OutOfMemory => return printAndReturnError("Error: OpenCL out of memory!\n"),
        cl.ClError.InvalidKernelName => return printAndReturnError("Error: Kernel name is invalid!\n"),
        cl.ClError.InvalidProgramExecutable => return printAndReturnError("Error: There is no successfully built executable for program!\n"),
        else => return printAndReturnError("Error: Failed to create OpenCL kernel!\n"),
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
    var cl_init_timer: ?std.time.Timer = if (properties.timed) std.time.Timer.start() catch null else null;
    const cl_bundle = try clInit(a);
    defer clFree(a, cl_bundle);
    var cl_program = try clGetProgram(cl_bundle.context);
    defer cl_program.release();
    cl_program.build(cl_bundle.device) catch return printAndReturnError("Error: Failed to build program!\n");
    var cl_kernel = try clGetKernel(cl_program, "gaussBlur");
    defer cl_kernel.release();
    if (cl_init_timer) |*timer| {
        const runtime = timer.read();
        const stderr = std.io.getStdErr().writer();
        stderr.print("Cl setup runtime: {d} ms\n", .{runtime / std.time.ns_per_ms}) catch {};
    }

    return switch (properties.source) {
        .files => handleFiles(a, properties, cl_bundle),
        .stdin => handleStdin(a, properties.silent, cl_bundle),
        .none => printAndReturnError("Error: No source files provided!\n"),
    };
}

fn handleStdin(a: std.mem.Allocator, silent: bool, cl_bundle: ClBundle) HandledError!void {
    const stdin = std.io.getStdIn().reader();
    const data = stdin.readAllAlloc(a, 1 << 30) catch |err| switch (err) {
        error.StreamTooLong => return printAndReturnError("Error: File exceeds maximum file size (1 GiB)\n"),
        error.OutOfMemory => return printAndReturnError("Error: Out of memory!\n"),
        else => return printAndReturnError("Error: Could not read input from file!\n"),
    };
    defer a.free(data);

    handleData(a, data, cl_bundle) catch |err| if (!silent) return err;
}

fn handleFiles(a: std.mem.Allocator, properties: args.Properties, cl_bundle: ClBundle) HandledError!void {
    var i: usize = 0;
    while (properties.getFile(i)) |file_name| : (i += 1) {
        handleFile(a, file_name, cl_bundle) catch |err| if (!properties.silent) return err;
    }
}

fn handleFile(a: std.mem.Allocator, file_name: []const u8, cl_bundle: ClBundle) HandledError!void {
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
    try handleData(a, file_data, cl_bundle);
}

fn handleData(a: std.mem.Allocator, file_data: []const u8, cl_bundle: ClBundle) HandledError!void {
    var image = Image.init(a, file_data) catch |err| switch (err) {
        error.Unsupported => return printAndReturnError("Error: NetPBM type is not supported!\n"),
        error.WrongMagicNumber => return printAndReturnError("Error: File type is not supported!\n"),
        error.CorruptedHeaderData => return printAndReturnError("Error: Could not read header!\n"),
        error.OutOfMemory => return printAndReturnError("Error: Memory allocation failed!\n"),
        error.UnreadableString => return printAndReturnError("Error: File data portion is corrupted!\n"),
        error.DamagedData => return printAndReturnError("Error: File data portion is corrupted!\n"),
    };
    defer image.deinit();

    _ = cl_bundle;
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
