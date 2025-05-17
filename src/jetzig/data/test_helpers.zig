const std = @import("std");
const jetzig = @import("../../jetzig.zig");

/// Creates a mock request for testing
pub fn createMockRequest(allocator: std.mem.Allocator) !*jetzig.http.Request {
    var req = try allocator.create(jetzig.http.Request);
    req.* = .{
        .allocator = allocator,
        .path = undefined,
        .method = undefined,
        .headers = undefined,
        .server = undefined,
        .httpz_request = undefined,
        .httpz_response = undefined,
        .response = undefined,
        .response_data = undefined,
        .query_params = null,
        .query_body = null,
        ._params_info = null,
        .multipart = null,
        .parsed_multipart = null,
        ._cookies = null,
        ._session = null,
        .body = "",
        .state = .initial,
        .dynamic_assigned_template = null,
        .layout = null,
        .layout_disabled = false,
        .redirect_state = null,
        .middleware_rendered = null,
        .middleware_data = undefined,
        .rendered_multiple = false,
        .rendered_view = null,
        .start_time = 0,
        .store = undefined,
        .cache = undefined,
        .repo = undefined,
        .global = undefined,
    };
    return req;
}