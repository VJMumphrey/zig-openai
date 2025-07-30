const std = @import("std");
const expect = std.testing.expect;

comptime {
    _ = @import("root.zig");
}

test "create client for local" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // there is a llamacpp server running locally for the tests
    var client = try openai.Client.init(allocator, null, "http://localhost:8080/v1");

    var messages = std.ArrayList(openai.Message).init(allocator);
    try messages.append(.{
        .role = "system",
        .content = "You are a helpful assistant. Return only with the word `True`.",
    });

    const payload = openai.ChatPayload{
                .model = "gemma-3n-E4B-it-GGUF",
                .messages = messages.items,
                .max_tokens = 5,
                .temperature = 0.1,
            };
    const response = try client.chat(payload, false);
    if (response.value.choices[0].message.content) |content| {
        const string = try std.fmt.allocPrint(allocator, "{any}", content);
        try expect(std.mem.eql(u8, string, "True"));
    }
    return;
}

// TODO maybe give fake api key for now and expect key failure
test "create client for remote" {}
