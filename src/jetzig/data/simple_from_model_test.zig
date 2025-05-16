const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");

test "simple fromModel with basic fields" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const User = struct {
        id: u64,
        name: []const u8,
        active: bool,
    };
    
    const user = User{
        .id = 42,
        .name = "John Doe",
        .active = true,
    };
    
    // Create a data object from the user struct
    const value = try jetzig.data.fromModel(allocator, user);
    
    // Verify it's an object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    
    // Verify basic fields
    try testing.expectEqual(@as(i64, 42), value.object.get("id").?.integer.value);
    try testing.expectEqualStrings("John Doe", value.object.get("name").?.string.value);
    try testing.expectEqual(true, value.object.get("active").?.boolean.value);
}