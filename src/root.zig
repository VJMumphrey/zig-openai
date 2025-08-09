//! Single file definition for the library.
const std = @import("std");
//const meta = @import("std").meta;

const Allocator = std.mem.Allocator;

pub const Usage = struct {
    prompt_tokens: u64,
    completion_tokens: ?u64,
    total_tokens: u64,
};

pub const Choice = struct {
    index: usize,
    finish_reason: ?[]const u8,
    message: struct {
        role: ?[]const u8 = null,
        content: ?[]const u8 = null,
    },
};

/// Simple chat api model
pub const ChatResponse = struct {
    id: []const u8,
    object: []const u8,
    created: u64,
    model: []const u8,
    choices: []Choice,
    usage: Usage,
};

pub const DeltaChoice = struct {
    index: usize,
    delta: struct {
        role: ?[]const u8 = null,
        content: ?[]const u8 = null,
    },
};

/// Streaming reponse api model
pub const StreamResponse = struct {
    id: []const u8,
    object: []const u8,
    created: u64,
    model: []const u8,
    choices: []DeltaChoice,
};

/// may convert to an enum at some point
pub const Role = struct {
    pub const system = "system";
    pub const user = "user";
    pub const assistant = "assistant";
};

/// Message definition with helpers
pub const Message = struct {
    role: []const u8,
    content: []const u8,

    // Add convenience constructors
    pub fn system(content: []const u8) Message {
        return .{ .role = Role.system, .content = content };
    }

    pub fn user(content: []const u8) Message {
        return .{ .role = Role.user, .content = content };
    }

    pub fn assistant(content: []const u8) Message {
        return .{ .role = Role.assistant, .content = content };
    }
};

pub const Model = struct {
    id: []const u8,
    object: []const u8,
    created: u64,
    owned_by: []const u8,
};

pub const ModelResponse = struct {
    object: []const u8,
    data: []Model,
};

const StreamReader = struct {
    arena: std.heap.ArenaAllocator,
    request: std.http.Client.Request,
    buffer: [2048]u8 = undefined,

    pub fn init(request: std.http.Client.Request) !StreamReader {
        return .{
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            .request = request,
        };
    }

    pub fn deinit(self: *StreamReader) void {
        self.arena.deinit();
        self.request.deinit();
    }

    pub fn next(self: *StreamReader) !?StreamResponse {
        const line = (try self.request.reader().readUntilDelimiterOrEof(&self.buffer, '\n')) orelse return null;
        try self.request.reader().skipBytes(1, .{}); // Skip second newline

        if (line.len == 0) return null;

        // Handle SSE format
        if (std.mem.startsWith(u8, line, "data: ")) {
            const data = line["data: ".len..];

            if (std.mem.eql(u8, data, "[DONE]")) return null;

            const parsed = try std.json.parseFromSlice(StreamResponse, self.arena.allocator(), data, .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            });

            return parsed.value;
        }

        return null;
    }
};

/// Payload model that used to expand and capture more features
/// of the openai api structure.
pub const ChatPayload = struct {
    model: []const u8,
    messages: []Message,
    max_tokens: ?u32,
    temperature: ?f32,
};

/// List of errors that can happen
const OpenAIError = error{
    BadRequest,
    Unauthorized,
    Forbidden,
    NotFound,
    TooManyRequests,
    InternalServerError,
    ServiceUnavailable,
    GatewayTimeout,
    Unknown,
};

/// Helper function that is used to parse out http errors from a server
/// and return them for use in the lib.
fn getError(status: std.http.Status) OpenAIError {
    const result = switch (status) {
        .bad_request => OpenAIError.BadRequest,
        .unauthorized => OpenAIError.Unauthorized,
        .forbidden => OpenAIError.Forbidden,
        .not_found => OpenAIError.NotFound,
        .too_many_requests => OpenAIError.TooManyRequests,
        .internal_server_error => OpenAIError.InternalServerError,
        .service_unavailable => OpenAIError.ServiceUnavailable,
        .gateway_timeout => OpenAIError.GatewayTimeout,
        else => OpenAIError.Unknown,
    };
    return result;
}

/// Client struct is used to handle the interactions from a consumer to a server.
/// This struct makes allocations with the given allocator.
pub const Client = struct {
    base_url: []const u8,
    api_key: ?[]const u8,
    organization_id: ?[]const u8,
    allocator: Allocator,
    http_client: std.http.Client,

    arena: std.heap.ArenaAllocator,

    /// init function for clients that creates a client with values set
    /// from the consumer.
    pub fn init(
        allocator: Allocator,
        organization_id: ?[]const u8,
        // don't supply for default OpenAI url
        url: ?[]const u8,
    ) !Client {
        const base_url: []const u8 = url orelse "https://api.openai.com/v1";

        var env = try std.process.getEnvMap(allocator);
        defer env.deinit();

        var api_key: []u8 = undefined;
        if (!std.mem.eql(u8, base_url, url.?)) {
            const _api_key = env.get("OPENAI_API_KEY") orelse return error.MissingAPIKey;
            api_key = try allocator.dupe(u8, _api_key);
        } else {
            api_key = "";
        }

        var arena = std.heap.ArenaAllocator.init(allocator); // Initialize arena
        errdefer arena.deinit(); // Ensure arena is deinitialized on error

        var http_client = std.http.Client{ .allocator = allocator };
        http_client.initDefaultProxies(arena.allocator()) catch |err| {
            http_client.deinit();
            return err;
        };

        return Client{
            .base_url = base_url,
            .allocator = allocator,
            .api_key = api_key,
            .organization_id = organization_id orelse "",
            .http_client = http_client,
            .arena = arena,
        };
    }

    /// helper function to modify headers to allows for api keys and set content type.
    fn get_headers(alloc: std.mem.Allocator, api_key: ?[]const u8) !std.http.Client.Request.Headers {
        const auth_header = try std.fmt.allocPrint(alloc, "Bearer {s}", .{api_key orelse ""});
        const headers = std.http.Client.Request.Headers{
            .content_type = .{ .override = "application/json" },
            .authorization = .{ .override = auth_header },
        };
        return headers;
    }

    /// helper function to perform the calling logic
    fn makeCall(self: *Client, endpoint: []const u8, body: []const u8, _: bool) !std.http.Client.Request {
        const headers = try get_headers(self.allocator, self.api_key);
        defer self.allocator.free(headers.authorization.override);

        var buf: [16 * 1024]u8 = undefined;

        const path = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.base_url, endpoint });
        defer self.allocator.free(path);
        const uri = try std.Uri.parse(path);

        var req = try self.http_client.open(.POST, uri, .{ .headers = headers, .server_header_buffer = &buf });
        errdefer req.deinit();

        req.transfer_encoding = .{ .content_length = body.len };

        try req.send();
        try req.writeAll(body);
        try req.finish();
        try req.wait();

        return req;
    }

    /// Makes a streaming chat completion request to the OpenAI API.
    /// Returns a StreamReader that can be used to read the response chunks.
    /// Caller must call deinit() on the returned StreamReader when done.
    pub fn streamChat(self: *Client, payload: ChatPayload, verbose: bool) !StreamReader {
        const options = .{
            .model = payload.model,
            .messages = payload.messages,
            .max_tokens = payload.max_tokens,
            .temperature = payload.temperature,
            .stream = true,
        };
        const body = try std.json.stringifyAlloc(self.allocator, options, .{});
        defer self.allocator.free(body);

        var req = try self.makeCall("/chat/completions", body, verbose);

        if (req.response.status != .ok) {
            const err = getError(req.response.status);
            req.deinit();
            return err;
        }

        return StreamReader.init(req);
    }

    /// Makes a chat completion request to the OpenAI API.
    /// Caller owns the returned memory and must call deinit() on the result.
    pub fn chat(self: *Client, payload: ChatPayload, verbose: bool) !std.json.Parsed(ChatResponse) {
        const options = .{
            .model = payload.model,
            .messages = payload.messages,
            .max_tokens = payload.max_tokens,
            .temperature = payload.temperature,
        };
        const body = try std.json.stringifyAlloc(self.allocator, options, .{
            .whitespace = .indent_2,
        });
        defer self.allocator.free(body);

        var req = try self.makeCall("/chat/completions", body, verbose);
        defer req.deinit();

        if (req.response.status != .ok) {
            const err = getError(req.response.status);
            req.deinit();
            return err;
        }

        const response = try req.reader().readAllAlloc(self.allocator, 1024 * 8);
        defer self.allocator.free(response);

        const parsed = try std.json.parseFromSlice(ChatResponse, self.allocator, response, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        });

        return parsed;
    }

    pub fn deinit(self: *Client) void {
        if (self.api_key) |key| {
            self.allocator.free(key);
        }
        if (self.organization_id) |org_id| {
            self.allocator.free(org_id);
        }
        self.http_client.deinit();
        self.arena.deinit();
    }
};

// goal is to create a local client an get a small message
// any model will do
test "create_client_local" {
    const gpa = std.testing.allocator;

    // there is a llamacpp server running locally for the tests
    var client = try Client.init(gpa, null, "http://localhost:8080/v1");
    defer client.deinit();
    
    var messages = std.ArrayList(Message).init(gpa);
    try messages.append(.{
        .role = "system",
        .content = "Return True.",
    });
    defer messages.deinit();

    try messages.append(.{
        .role = "user",
        .content = "Return True.",
    });

    const payload = ChatPayload{
        .model = "gemma-3n-E4B-it-GGUF",
        .messages = messages.items,
        .max_tokens = 1,
        .temperature = 0.1,
    };

    // might be worth it to write a switch here for error handeling
    // as a consumer
    const response = try client.chat(payload, false);
    defer response.deinit();

    if (response.value.choices[0].message.content) |content| {
        _ = try std.fmt.allocPrint(gpa, "{?s}", .{content});
        try std.testing.expect(content.len > 0);
    }
}

// TODO maybe give fake api key for now and expect key failure
test "create client for remote" {
    return error.SkipZigTest;
}
