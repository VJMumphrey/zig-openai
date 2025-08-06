const std = @import("std");
const OpenAI = @import("zig_openai");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // gather the cli args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) return error.ExpectedArgument;

    for (args, 0..) |arg, i| {
        const string = try std.fmt.allocPrint(allocator, "arg {d}: {s}\n", .{ i, arg });
        allocator.free(string);
    }

    var client = try OpenAI.Client.init(allocator, null, "http://localhost:8080/v1");

    var messages = std.ArrayList(OpenAI.Message).init(allocator);
    defer messages.deinit();

    try messages.append(.{
        .role = "system",
        .content = "Act as a helpful AI Assitant",
    });

    try messages.append(.{
        .role = "user",
        // change to be cli inputs
        .content = args[1],
    });

    const payload = OpenAI.ChatPayload{
        .model = "gemma-3n-E4B-it-GGUF",
        .messages = messages.items,
        .max_tokens = 1000,
        .temperature = 0.2,
    };

    const response = try client.chat(payload, false);
    defer response.deinit();
    if (response.value.choices[0].message.content) |content| {
        std.debug.print("Result: {s}\n", .{content});
    }
}
