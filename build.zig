const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("zig_openai", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const stream_example = b.addExecutable(.{
        .name = "stream_cli",
        .root_module = module,
    });
    stream_example.root_module.addImport("zig_openai", module);
}
