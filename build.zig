const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("glfw", "src/main.zig");
    exe.linkLibC();
    exe.linkSystemLibrary("raylib");
    exe.addIncludeDir("src/workaround/");
    exe.addCSourceFile("src/workaround/workaround.c", &[_][]const u8{});
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
