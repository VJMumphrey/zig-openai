# zig-openai

A simple OpenAI API client (and maybe server at some point) for Zig with streaming support.

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
Currently the library is held at 0.14.1 of zig until the IO changes from 0.15 are stabble enough
in the dev branch. This will not work on zig master at the moment.

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

## Running Examples
The system is like [flags](https://github.com/joegm/flags/tree/main).
```bash
zig build example -Dexample=<name> -- <arguments...>
```
This will stay untill things need to be changed or updated.

## Testing

For testing there are two tests included in bottom of root.zig.
Remote will be implemented at some point. To test run,
```bash
zig test src/root.zig
```
There are plans to improve the testing since this system will get more complicated as more of the 
standard is implemented.

## Documentation
You can build the docs the standard way with,
```bash
zig build-lib -femit-docs src/root.zig
```
Then run a python server to view the documentation in your browser with,
```bash
python -m http.server 8000 -b 127.0.0.1 docs/
```
Note that this command is ran in the root of the project.

## Credit
Forked from FOLLGAD [github](https://github.com/FOLLGAD).
