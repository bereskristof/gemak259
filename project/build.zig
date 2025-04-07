const std = @import("std");

const name = "_c";

const BuildZon = struct {
    name: enum { _c },
    version: []const u8,
    fingerprint: u128,
    minimum_zig_version: []const u8,
    paths: []const []const u8,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Setting .name & .version during build
    const build_config = b.addOptions();
    const build_zon: BuildZon = @import("build.zig.zon");
    build_config.addOption([]const u8, "name", name);
    build_config.addOption([]const u8, "version", build_zon.version);
    exe_mod.addOptions("build_config", build_config);

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });

    // OpenCl libs
    exe.addIncludePath(.{ .cwd_relative = "include/" });
    exe.addLibraryPath(.{ .cwd_relative = "lib/" });
    exe.linkSystemLibrary("OpenCl.dll");
    exe.linkLibC();

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
