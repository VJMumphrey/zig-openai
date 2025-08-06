const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("zig_openai", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const example_step = b.step("example", "Run the example");
    const example_option = b.option(
        enum {
            stream,
            chat,
            // more later
        },
        "example",
        "Example to run for the example step, default is stream for now.",
    ) orelse .stream;

    const examples = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path(b.fmt("examples/{s}.zig", .{@tagName(example_option)})),
        .target = target,
        .optimize = optimize,
    });
    examples.root_module.addImport("zig_openai", module);
    const run_example = b.addRunArtifact(examples);
    if (b.args) |args| run_example.addArgs(args);
    example_step.dependOn(&run_example.step);
}
