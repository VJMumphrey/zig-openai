# zig-openai

A simple OpenAI API client for Zig with streaming support.

Find examples in the [`examples`](./examples) directory.

## Usage

With streaming:

```zig
const std = @import("std");
const OpenAI = @import("zig-openai");

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

This pulls the latest release from main.
Eventually tagged releases will be introduced for version locking.
```bash
$ zig fetch --save git+https://github.com/VJMumphrey/zig-openai
```

and add `zig-openai` to your `build.zig` file:

```zig
const zig_openai = b.dependency("zig_openai", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zig_openai", module.module("zig_openai"));
```

## Usage

See the `examples` directory for usage examples.

## Credit
Forked from FOLLGAD [github](https://github.com/FOLLGAD).
