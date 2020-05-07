const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("pixelcode", "src/main.zig");
    exe.linkLibC();
    
    // raylib
    exe.linkSystemLibrary("raylib");
    exe.addIncludeDir("src/workaround/");
    exe.addCSourceFile("src/workaround/workaround.c", &[_][]const u8{});
    
    // tree-sitter
    if (mode == .ReleaseFast) {
        exe.addCSourceFile("deps/build/tree-sitter/lib/src/lib.c", &[_][]const u8{});
        exe.addIncludeDir("deps/build/tree-sitter/lib/src");
        exe.addIncludeDir("deps/build/tree-sitter/lib/include");
    } else {
        exe.addObjectFile("deps/build/tree-sitter/lib/src/lib.o");
    }
    exe.addIncludeDir("deps/build/tree-sitter/lib/include");
    exe.addCSourceFile("deps/build/tree-sitter-zig/src/parser.c", &[_][]const u8{});
    
    
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
