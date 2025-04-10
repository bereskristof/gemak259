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

const HandlingError = error{
    FileNotFound,
    AccessDenied,
    SourceIsMissing,
    OutOfMemory,
    FileIsDamaged,
    Unsupported,
    UnknownError,
};

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
        .Version => stdout.print("{s}\n", .{version}) catch return exit_complete_failure,
        else => _ = handleInputs(allocator, run_config) catch |err| switch (err) {
            error.FileNotFound => return errorExit("Error: File not found!\n"),
            error.AccessDenied => return errorExit("Error: Access denied!\n"),
            error.SourceIsMissing => return errorExit("Error: No source provided!\n"),
            error.OutOfMemory => return errorExit("Error: Not enough memory available!\n"),
            error.FileIsDamaged => return errorExit("Error: File data is corrupted!\n"),
            error.Unsupported => return errorExit("Error: File type is unsupported!\n"),
            error.UnknownError => return errorExit("Error: Unknown!\n"),
        },
    }

    return exit_success;
}

fn handleInputs(a: std.mem.Allocator, properies: args.Properties) HandlingError!void {
    switch (properies.source) {
        .files => {
            var i: usize = 0;
            while (properies.getFile(i)) |file_name| : (i += 1) {
                handleFile(a, file_name) catch |err| if (!properies.silent) {
                    return err;
                } else {
                    return;
                };
            }
        },
        .stdin => {
            const stdin = std.io.getStdIn().reader();
            const data = stdin.readAllAlloc(a, 1 << 30) catch return HandlingError.OutOfMemory;
            defer a.free(data);

            handleData(a, data) catch |err| if (!properies.silent) {
                return err;
            } else {
                return;
            };

            return;
        },
        .none => return HandlingError.SourceIsMissing,
    }
}

fn handleFile(a: std.mem.Allocator, file_name: []const u8) HandlingError!void {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(file_name, .{}) catch |err| switch (err) {
        error.FileNotFound => return HandlingError.FileNotFound,
        error.AccessDenied => return HandlingError.AccessDenied,
        else => return HandlingError.UnknownError,
    };
    defer file.close();

    const file_data = file.readToEndAlloc(a, 1 << 30) catch return HandlingError.OutOfMemory;
    defer a.free(file_data);
    try handleData(a, file_data);
}

fn handleData(a: std.mem.Allocator, file_data: []const u8) HandlingError!void {
    var image = Image.init(a, file_data) catch |err| switch (err) {
        error.Unsupported => return HandlingError.Unsupported,
        error.WrongMagicNumber => return HandlingError.Unsupported,
        error.CorruptedHeaderData => return HandlingError.FileIsDamaged,
        error.OutOfMemory => return HandlingError.OutOfMemory,
        error.UnreadableString => return HandlingError.FileIsDamaged,
        error.DamagedData => return HandlingError.FileIsDamaged,
    };
    defer image.deinit();

    image.print() catch {};
}

fn errorExit(comptime msg: []const u8) u8 {
    const stderr = std.io.getStdErr().writer();
    _ = stderr.write(msg) catch {
        return exit_complete_failure;
    };
    return exit_failure;
}
