const std = @import("std");
const OpenAI = @import("zig_openai");

// this is example runs a simple chat
// BUG: crashes after single run
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize OpenAI client
    // this is for llamacpp but should work for other openai servers 
    var openai = try OpenAI.Client.init(allocator, null, "http://localhost:8080/v1");

    const stdin = std.io.getStdIn().reader();
    var buf_reader = std.io.bufferedReader(stdin);
    const reader = buf_reader.reader();

    const stdout = std.io.getStdOut().writer();
    var buf_writer = std.io.bufferedWriter(stdout);
    const writer = buf_writer.writer();

    var buffer: [1024]u8 = undefined;

    var messages = std.ArrayList(OpenAI.Message).init(allocator);
    try messages.append(.{
        .role = "system",
        .content = "You are a helpful assistant",
    });

    while (true) {
        try writer.writeAll("> ");
        try buf_writer.flush();

        if (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            const user_message = OpenAI.Message{
                .role = "user",
                .content = try allocator.dupe(u8, line),
            };
            try messages.append(user_message);

            const payload = OpenAI.ChatPayload{
                .model = "gemma-3n-E4B-it-Q4_K_M.gguf",
                .messages = messages.items,
                .max_tokens = 1000,
                .temperature = 0.2,
            };

            var stream = try openai.streamChat(payload, false);
            defer stream.deinit();
            var responseString: []const u8 = "";
            while (try stream.next()) |response| {
                if (response.choices[0].delta.content) |content| {
                    try writer.writeAll(content);
                    try buf_writer.flush();
                    responseString = try std.fmt.allocPrint(allocator, "{s}{s}", .{ responseString, content });
                }
            }

            writer.writeAll("\n") catch unreachable;
            buf_writer.flush() catch unreachable;

            try messages.append(
                OpenAI.Message{
                    .role = "assistant",
                    .content = responseString,
                },
            );
        } else {
            break; // EOF reached
        }
    }
}
