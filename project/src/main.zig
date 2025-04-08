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
        else => _ = handleInputs(run_config) catch |err| switch (err) {
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

fn handleInputs(properies: args.Properties) HandlingError!void {
    switch (properies.source) {
        .files => {
            var i: usize = 0;
            while (properies.getFile(i)) |file_name| : (i += 1) {
                handleFile(file_name) catch |err| if (!properies.silent) {
                    return err;
                } else {
                    return;
                };
            }
        },
        .stdin => {
            return; // TODO: Replace with implementation
        },
        .none => return HandlingError.SourceIsMissing,
    }
}

fn handleFile(file_name: []const u8) HandlingError!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var image = Image.initFromFile(allocator, file_name) catch |err| switch (err) {
        error.FileNotFound => return HandlingError.FileNotFound,
        error.AccessDenied => return HandlingError.AccessDenied,
        error.Unsupported => return HandlingError.Unsupported,
        error.WrongMagicNumber => return HandlingError.Unsupported,
        error.CorruptedHeaderData => return HandlingError.FileIsDamaged,
        error.OutOfMemory => return HandlingError.OutOfMemory,
        error.UnreadableString => return HandlingError.FileIsDamaged,
        error.DamagedData => return HandlingError.FileIsDamaged,
        else => return HandlingError.UnknownError,
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
