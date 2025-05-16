const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");

test "minimal direct string creation" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a simple string value
    var data_obj = jetzig.data.Data.init(allocator);
    const str_val = data_obj.string("Test String");
    
    // Verify the string value
    try testing.expect(@as(jetzig.data.ValueType, str_val.*) == .string);
    try testing.expectEqualStrings("Test String", str_val.string.value);
    
    // Add to object and verify
    var root = try data_obj.root(.object);
    try root.put("test_key", str_val);
    
    const retrieved = root.object.get("test_key").?;
    try testing.expect(@as(jetzig.data.ValueType, retrieved.*) == .string);
    try testing.expectEqualStrings("Test String", retrieved.string.value);
}