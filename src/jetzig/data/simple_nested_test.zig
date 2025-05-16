const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");

test "zmplValue with nested struct" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const SimpleUser = struct {
        name: []const u8,
        age: u32,
    };
    
    const user = SimpleUser{ 
        .name = "Test User", 
        .age = 30 
    };
    
    // Create a data object
    var data_obj = jetzig.data.Data.init(allocator);
    var root = try data_obj.root(.object);
    
    // Set the user directly using zmplValue
    try root.put("user", try jetzig.data.zmplValue(user, allocator));
    
    // Verify the data
    const user_obj = root.object.get("user").?;
    try testing.expect(@as(jetzig.data.ValueType, user_obj.*) == .object);
    
    // Check name field
    const name_val = user_obj.object.get("name").?;
    try testing.expect(@as(jetzig.data.ValueType, name_val.*) == .string);
    try testing.expectEqualStrings("Test User", name_val.string.value);
    
    // Check age field
    const age_val = user_obj.object.get("age").?;
    try testing.expect(@as(jetzig.data.ValueType, age_val.*) == .integer);
    try testing.expectEqual(@as(i64, 30), age_val.integer.value);
}

test "zmplValue with simple array" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    
    // Create a data object
    var data_obj = jetzig.data.Data.init(allocator);
    var root = try data_obj.root(.object);
    
    // Set the numbers directly using zmplValue
    try root.put("numbers", try jetzig.data.zmplValue(&numbers, allocator));
    
    // Verify the data
    const nums_arr = root.object.get("numbers").?;
    try testing.expect(@as(jetzig.data.ValueType, nums_arr.*) == .array);
    try testing.expectEqual(@as(usize, 5), nums_arr.array.array.items.len);
    
    // Check individual values
    for (0..5) |i| {
        const val = nums_arr.array.array.items[i];
        try testing.expect(@as(jetzig.data.ValueType, val.*) == .integer);
        try testing.expectEqual(@as(i64, @intCast(i + 1)), val.integer.value);
    }
}