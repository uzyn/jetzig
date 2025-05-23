const std = @import("std");
const jetzig = @import("jetzig");

pub fn index(request: *jetzig.Request) !jetzig.View {
    var root = try request.data(.object);

    const session = try request.session();

    if (session.get("message")) |message| {
        try root.put("message", message);
    } else {
        try root.put("message", "No message saved yet");
    }

    return request.render(.ok);
}

pub fn edit(id: []const u8, request: *jetzig.Request) !jetzig.View {
    try request.server.logger.INFO("id: {s}", .{id});
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {
    const params = try request.params();
    var session = try request.session();

    if (params.get("message")) |message| {
        if (std.mem.eql(u8, message.string.value, "delete")) {
            _ = try session.remove("message");
        } else {
            try session.put("message", message);
        }
    }

    return request.redirect("/session", .moved_permanently);
}
