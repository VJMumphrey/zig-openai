const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("zig-openai", .{
        .root_source_file = b.path("src/llm.zig"),
    });

    const stream_example = b.addExecutable(.{
        .name = "stream-cli",
        .root_source_file = b.path("examples/stream-cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    stream_example.root_module.addImport("zig-openai", module);
}
