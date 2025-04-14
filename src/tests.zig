const std = @import("std");
const jetzig = @import("jetzig.zig");

test {
    std.debug.assert(jetzig.jetquery.jetcommon == jetzig.zmpl.jetcommon);
    std.debug.assert(jetzig.zmpl.jetcommon == jetzig.jetcommon);
    _ = @import("jetzig/http/Query.zig");
    _ = @import("jetzig/http/Headers.zig");
    _ = @import("jetzig/http/Cookies.zig");
    _ = @import("jetzig/http/Session.zig");
    _ = @import("jetzig/http/Path.zig");
    _ = @import("jetzig/jobs/Job.zig");
    _ = @import("jetzig/mail/Mail.zig");
    _ = @import("jetzig/loggers/LogQueue.zig");
}

test "format parameters" {
    var allocator = std.testing.allocator;
    
    // Create test data
    var data = jetzig.data.Data.init(allocator);
    defer data.deinit();
    
    var root = try data.root(.object);
    
    try root.put("string_value", data.string("test string"));
    try root.put("int_value", data.int(123));
    try root.put("bool_value", data.boolean(true));
    
    // Create nested structure
    var nested = try data.object();
    try nested.put("nested_key", data.string("nested value"));
    try root.put("object_value", nested);
    
    // Create an array
    var array = try data.array();
    try array.append(data.string("item1"));
    try array.append(data.int(42));
    try root.put("array_value", array);
    
    // Create a simple mock request
    var request = MockRequest{ .allocator = allocator };
    
    // Format parameters
    const formatted = try request.formatParameters(root);
    defer allocator.free(formatted);
    
    // Simple verification - make sure the output contains expected values
    try std.testing.expect(std.mem.indexOf(u8, formatted, "test string") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "true") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "nested value") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "item1") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "42") != null);
}

// Simple mock request for testing that implements only the formatParameters function
const MockRequest = struct {
    allocator: std.mem.Allocator,
    
    pub fn formatParameters(self: MockRequest, params_value: *const jetzig.data.Value) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        const writer = buffer.writer();
        
        try writer.writeAll("Params ");
        try formatParameterValue(params_value, writer);

        return buffer.toOwnedSlice();
    }
    
    fn formatParameterValue(value: *const jetzig.data.Value, writer: anytype) !void {
        switch (value.*) {
            .string => |s| try writer.print("\"{s}\"", .{s.value}),
            .int => |i| try writer.print("{d}", .{i.value}),
            .float => |f| try writer.print("{d}", .{f.value}),
            .bool => |b| try writer.print("{}", .{b.value}),
            .null => try writer.writeAll("null"),
            .array => |a| {
                try writer.writeAll("[");
                for (a.items(), 0..) |item, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try formatParameterValue(item, writer);
                }
                try writer.writeAll("]");
            },
            .object => |o| {
                try writer.writeAll("{\n");
                var it = o.iterator();
                var is_first = true;
                while (it.next()) |entry| {
                    if (!is_first) try writer.writeAll(",\n");
                    is_first = false;
                    try writer.print("  {s}: ", .{entry.key_ptr.*});
                    try formatParameterValue(entry.value_ptr, writer);
                }
                try writer.writeAll("\n}");
            },
        }
    }
};
