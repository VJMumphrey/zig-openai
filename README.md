# zig-ai

A simple OpenAI API client for Zig with streaming support.

Find examples in the [`examples`](./examples) directory.

## Usage

With streaming:

```zig
const std = @import("std");
const OpenAI = @import("zig-ai");

pub fn main() !void {
    // ...

    var messages = std.ArrayList(OpenAI.Message).init(allocator);
    try messages.append(.{
        .role = "system",
        .content = "You are a helpful assistant",
    });
    try messages.append(.{
        .role = "user",
        .content = "User message here",
    });

    const payload = OpenAI.ChatPayload{
        .model = "gpt-4o",
        .messages = messages.items,
        .max_tokens = 1000,
        .temperature = 0.2,
    };

    var stream = try openai.streamChat(payload, false);
    defer stream.deinit();

    while (try stream.next()) |response| {
        // Stream the response to stdout
        if (response.choices[0].delta.content) |content| {
            try writer.writeAll(content);
            try buf_writer.flush();
        }
    }
}
```

## Installation

```bash
$ zig fetch --save git+https://github.com/VJMumphrey/zig-ai
```

and add `zig-ai` to your `build.zig` file:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "stream-cli",
        .root_source_file = b.path("examples/stream-cli.zig"),
        .target = target,
        .optimize = optimize,
    });

    const module = b.dependency("zig-ai", .{
        .root_source_file = b.path("src/llm.zig"),
    });
    exe.root_module.addImport("zig-ai", module.module("zig-ai"));
}
```

## Usage

See the `examples` directory for usage examples.
