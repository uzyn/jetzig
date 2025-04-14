const std = @import("std");
const jetzig = @import("../../../jetzig.zig");

// Format function to make jetzig.data.Value work with std.debug.print
pub fn format(
    value: *const jetzig.data.Value,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;

    // Simply reuse the existing formatParameterValue implementation
    switch (value.*) {
        .string => |s| try writer.print("\"{s}\"", .{s.value}),
        .integer => |i| try writer.print("{d}", .{i.value}),
        .float => |f| try writer.print("{d}", .{f.value}),
        .boolean => |b| try writer.print("{}", .{b.value}),
        .null => try writer.writeAll("null"),
        .datetime => |dt| try writer.print("datetime: {}", .{dt.value}),
        .array => |a| {
            try writer.writeAll("[");
            for (a.items(), 0..) |item, i| {
                if (i > 0) try writer.writeAll(", ");
                try format(item, fmt, options, writer);
            }
            try writer.writeAll("]");
        },
        .object => |o| {
            try writer.writeAll("{\n");
            var is_first = true;
            for (o.items()) |entry| {
                if (!is_first) try writer.writeAll(",\n");
                is_first = false;
                try writer.print("  {s}: ", .{entry.key});
                try format(entry.value, fmt, options, writer);
            }
            try writer.writeAll("\n}");
        },
    }
}
