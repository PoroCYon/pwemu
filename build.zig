
const std = @import("std");

const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("pwemu", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addCSourceFile("ext/libco/libco.c", &[_][]const u8{
        "-std=gnu11",
        "-Wall","-Wextra","-Weverything",
        "-I.ext/libco/"//, "-I./inc/",
    });
    exe.addIncludeDir("ext/libco/");

    //exe.addCSourceFile("src/h8300h.c", &[_][]const u8{
    //    "-std=gnu11",
    //    "-Wall","-Wextra","-Weverything",
    //    "-I.ext/libco/", "-I./inc/",
    //});
    //exe.addIncludeDir("inc/");
    exe.linkSystemLibrary("c");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

