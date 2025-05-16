const std = @import("std");
const testing = std.testing;
const data = @import("../data.zig");
const zmpl = @import("zmpl").zmpl;

// Test models with nested arrays
const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
    favorites: []const Favorite,
    tags: []const []const u8,
};

const Favorite = struct {
    id: i64,
    title: []const u8,
};

const Comment = struct {
    id: i64,
    text: []const u8,
    nested: NestedStruct,
    array_of_structs: []const NestedStruct,
};

const NestedStruct = struct {
    value: []const u8,
    items: []const []const u8,
};

// This test will fail initially because there's no fromModel function yet
test "fromModel automatically handles arrays and objects" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create test data with nested arrays
    const favorites = [_]Favorite{
        .{ .id = 1, .title = "Favorite 1" },
        .{ .id = 2, .title = "Favorite 2" },
    };
    
    const tags = [_][]const u8{ "tag1", "tag2", "tag3" };
    
    const user = User{
        .id = 101,
        .name = "Test User",
        .email = "user@example.com",
        .favorites = &favorites,
        .tags = &tags,
    };
    
    // Call the function that doesn't exist yet - this should fail
    const result = try data.fromModel(allocator, user);
    
    // Verify the result structure
    try testing.expect(@as(data.ValueType, result.*) == .object);
    
    const obj = result.object;
    try testing.expectEqual(@as(i64, 101), obj.get("id").?.integer.value);
    try testing.expectEqualStrings("Test User", obj.get("name").?.string.value);
    
    // Check if arrays were properly converted
    try testing.expect(@as(data.ValueType, obj.get("favorites").*) == .array);
    const favorites_arr = obj.get("favorites").?.array;
    try testing.expectEqual(@as(usize, 2), favorites_arr.count());
    
    // Check first favorite
    const fav1 = favorites_arr.get(0).?.object;
    try testing.expectEqual(@as(i64, 1), fav1.get("id").?.integer.value);
    try testing.expectEqualStrings("Favorite 1", fav1.get("title").?.string.value);
    
    // Check tags array
    try testing.expect(@as(data.ValueType, obj.get("tags").*) == .array);
    const tags_arr = obj.get("tags").?.array;
    try testing.expectEqual(@as(usize, 3), tags_arr.count());
    try testing.expectEqualStrings("tag1", tags_arr.get(0).?.string.value);
}

// Test deeply nested arrays and objects
test "fromModel handles deeply nested structures" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const nested_items = [_][]const u8{"item1", "item2"};
    const nested_struct = NestedStruct{
        .value = "nested value",
        .items = &nested_items,
    };
    
    const array_items = [_]NestedStruct{
        .{
            .value = "array item 1",
            .items = &[_][]const u8{"a", "b"},
        },
        .{
            .value = "array item 2",
            .items = &[_][]const u8{"c", "d"},
        },
    };
    
    const comment = Comment{
        .id = 42,
        .text = "Test comment",
        .nested = nested_struct,
        .array_of_structs = &array_items,
    };
    
    // Call the function that doesn't exist yet - this should fail
    const result = try data.fromModel(allocator, comment);
    
    // Verify the deep nested structure
    try testing.expect(@as(data.ValueType, result.*) == .object);
    
    const obj = result.object;
    try testing.expectEqual(@as(i64, 42), obj.get("id").?.integer.value);
    
    // Check nested struct
    const nested = obj.get("nested").?.object;
    try testing.expectEqualStrings("nested value", nested.get("value").?.string.value);
    
    // Check items array in nested struct
    const items = nested.get("items").?.array;
    try testing.expectEqual(@as(usize, 2), items.count());
    try testing.expectEqualStrings("item1", items.get(0).?.string.value);
    
    // Check array of structs
    const array_of_structs = obj.get("array_of_structs").?.array;
    try testing.expectEqual(@as(usize, 2), array_of_structs.count());
    
    // Check first struct in array
    const first = array_of_structs.get(0).?.object;
    try testing.expectEqualStrings("array item 1", first.get("value").?.string.value);
    
    // Check items in first struct
    const first_items = first.get("items").?.array;
    try testing.expectEqual(@as(usize, 2), first_items.count());
    try testing.expectEqualStrings("a", first_items.get(0).?.string.value);
}
