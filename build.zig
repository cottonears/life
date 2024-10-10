const std = @import("std");

pub fn build(b: *std.Build) !void {

    // Below code is Based on Andrew Kelly's build.zig in his SDL2 demo:
    // https://github.com/andrewrk/sdl-zig-demo
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "life",
        .root_source_file = b.path("src/main.zig"),
        .optimize = b.standardOptimizeOption(.{}),
        .target = target,
    });

    if (target.query.isNativeOs() and target.result.os.tag == .linux) {
        exe.linkSystemLibrary("SDL2");
        exe.linkLibC();
    } else {
        return error.OsNotSupported;
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
