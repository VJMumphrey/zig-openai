const std = @import("std");
const OpenAI = @import("zig_openai");

// this is example runs a simple chat
// BUG: crashes after single run
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa = gpa.allocator();

    // Initialize OpenAI client
    // this is for llamacpp but should work for other openai compliant servers 
    var openai = try OpenAI.Client.init(gpa, null, "http://localhost:8080/v1");
    defer openai.deinit();

    // setup IO for read and write to shell
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;

    const stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    const stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var buffer: [1024]u8 = undefined;

    // create the array to store the conversation in
    var messages = std.ArrayList(OpenAI.Message).empty;
    defer messages.deinit(gpa);

    // system prompt
    try messages.append(
        gpa,
        .{
        .role = "system",
        .content = "You are a helpful assistant",
    });

    while (true) {
        try stdout.writeAll("> ");
        try stdout.flush();

        // TODO: fix for 0.15.1
        if (try stdin.allocatorreadUntilDelimiterOrEof(&buffer, '\n')) |line| {
            const user_message = OpenAI.Message{
                .role = "user",
                .content = try gpa.dupe(u8, line),
            };
            try messages.append(gpa, user_message);

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
                    try stdout.writeAll(content);
                    try stdout.flush();
                    responseString = try std.fmt.allocPrint(allocator, "{s}{s}", .{ responseString, content });
                }
            }

            stdout.writeAll("\n") catch unreachable;
            stdout.flush() catch unreachable;

            try messages.append(
                gpa,
                .{
                    .role = "assistant",
                    .content = responseString,
                },
            );
        } else {
            break; // EOF reached
        }
    }
}
