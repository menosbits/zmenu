const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    if (target.query.os_tag) |t| {
        if (t != .linux) {
            std.debug.print("zmenu is designed for GNU/Linux only; target {s} is not allowed.\n", .{@tagName(t)});
            return;
        }
    }

    const zigzag = b.dependency("zigzag", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zmenu",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    b.installArtifact(exe);

    exe.root_module.addImport("zigzag", zigzag.module("zigzag"));

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const apps = b.addModule("apps", .{
        .root_source_file = b.path("src/apps.zig"),
        .target = target,
    });
    const app_tests = b.addTest(.{
        .root_module = apps,
    });
    const run_app_tests = b.addRunArtifact(app_tests);

    const utils = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
        .target = target,
    });
    const utils_tests = b.addTest(.{
        .root_module = utils,
    });
    const run_utils_tests = b.addRunArtifact(utils_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_app_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_utils_tests.step);
}
