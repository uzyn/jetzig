const std = @import("std");
const testing = std.testing;
const data = @import("../data.zig");
const zmpl = @import("zmpl").zmpl;

// Imported for ComplexType definition
const model_to_data = @import("model_to_data.zig");

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

// Test of the fromModel function and handling of arrays
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
    
    // Test array of Favorites
    const favorites_result = try data.fromModelWithOptions(allocator, &favorites, .{});
    try testing.expect(@as(data.ValueType, favorites_result.*) == .array);
    
    const favorites_arr = favorites_result.array;
    try testing.expectEqual(@as(usize, 2), favorites_arr.count());
    
    // Check first favorite
    const fav1 = favorites_arr.get(0).?.object;
    try testing.expectEqual(@as(i64, 1), fav1.get("id").?.integer.value);
    try testing.expectEqualStrings("Favorite 1", fav1.get("title").?.string.value);
    
    // Test array of strings
    const tags_result = try data.fromModelWithOptions(allocator, &tags, .{});
    try testing.expect(@as(data.ValueType, tags_result.*) == .array);
    
    const tags_arr = tags_result.array;
    try testing.expectEqual(@as(usize, 3), tags_arr.count());
    
    // Get and check tag1 - we expect a string value
    const tag1_value = tags_arr.get(0).?;
    try testing.expect(@as(data.ValueType, tag1_value.*) == .string);
    try testing.expectEqualStrings("tag1", tag1_value.string.value);
    
    // Test a user object
    const user = User{
        .id = 101,
        .name = "Test User",
        .email = "user@example.com",
        .favorites = &favorites,
        .tags = &tags,
    };
    
    const user_result = try data.fromModel(allocator, user);
    try testing.expect(@as(data.ValueType, user_result.*) == .object);
    
    const user_obj = user_result.object;
    try testing.expectEqual(@as(i64, 101), user_obj.get("id").?.integer.value);
    try testing.expectEqualStrings("Test User", user_obj.get("name").?.string.value);
}

// Test arrays of complex objects
test "fromModel handles deeply nested structures" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Test array of strings
    const nested_items = [_][]const u8{"item1", "item2"};
    const items_result = try data.fromModel(allocator, &nested_items);
    try testing.expect(@as(data.ValueType, items_result.*) == .array);
    const items_arr = items_result.array;
    try testing.expectEqual(@as(usize, 2), items_arr.count());
    
    // Get and check item1 - we expect a string value
    const item1_value = items_arr.get(0).?;
    try testing.expect(@as(data.ValueType, item1_value.*) == .string);
    try testing.expectEqualStrings("item1", item1_value.string.value);
    
    // Test array of structs
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
    
    const structs_result = try data.fromModel(allocator, &array_items);
    try testing.expect(@as(data.ValueType, structs_result.*) == .array);
    const structs_arr = structs_result.array;
    try testing.expectEqual(@as(usize, 2), structs_arr.count());
    
    // Check first nested struct
    const first = structs_arr.get(0).?.object;
    try testing.expectEqualStrings("array item 1", first.get("value").?.string.value);
}

// Test case to demonstrate the NoSpaceLeft error with a large string
test "fromModel with large string should handle NoSpaceLeft error" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Define a model with a large string field
    const LargeStringModel = struct {
        id: i64,
        name: []const u8,
        description: []const u8, // This will be a large string
    };
    
    // Create a string that exceeds the 512-byte buffer
    const large_string = try allocator.alloc(u8, 600);
    @memset(large_string, 'X');
    
    // Create the model with the large string
    const model = LargeStringModel{
        .id = 1,
        .name = "Test Model",
        .description = large_string,
    };
    
    // This should fail with NoSpaceLeft error when using the current implementation
    _ = try data.fromModel(allocator, model);
}

// Test case to demonstrate the NoSpaceLeft error with a complex non-struct type
test "fromModel with complex type should handle NoSpaceLeft error" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Define a complex type that will produce a large formatted output
    const ComplexType = struct {
        id: i64,
        // This is a complex type that isn't easily convertible
        value: @TypeOf(@as(anyerror, error.Overflow)),
    };
    
    // Create a model with the complex error type
    const model = ComplexType{
        .id = 1,
        .value = error.ThisWillCauseAVeryLongStringWhenFormattedToFitInTheFixedSizeBuffer,
    };
    
    // This should fail with NoSpaceLeft error when using the current implementation
    _ = try data.fromModel(allocator, model);
}

// Test case to demonstrate the NoSpaceLeft error with a deeply nested structure
test "fromModel with deeply nested structure should handle NoSpaceLeft error" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a deeply nested structure that will exceed the buffer when formatted
    const DeepNestedModel = struct {
        level1: struct {
            level2: struct {
                level3: struct {
                    level4: struct {
                        level5: struct {
                            value: []const u8,
                        },
                    },
                },
            },
        },
    };
    
    // Create a string for the deepest level
    const deep_value = try allocator.alloc(u8, 300);
    @memset(deep_value, 'Y');
    
    // Create the deeply nested model
    const model = DeepNestedModel{
        .level1 = .{
            .level2 = .{
                .level3 = .{
                    .level4 = .{
                        .level5 = .{
                            .value = deep_value,
                        },
                    },
                },
            },
        },
    };
    
    // This should fail with NoSpaceLeft error when using the current implementation
    _ = try data.fromModel(allocator, model);
}

// Test case to demonstrate the NoSpaceLeft error with a large array of values
test "fromModel with large array should handle NoSpaceLeft error" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a model with a large array
    const LargeArrayModel = struct {
        id: i64,
        items: []const []const u8,
    };
    
    // Create an array with many entries that together exceed the buffer size
    var items = std.ArrayList([]const u8).init(allocator);
    defer items.deinit();
    
    // Add enough entries to exceed the buffer
    for (0..30) |i| {
        const item = try std.fmt.allocPrint(allocator, "This is item number {d} with some extra text to make it longer than usual and cause a buffer overflow", .{i});
        try items.append(item);
    }
    
    const model = LargeArrayModel{
        .id = 1,
        .items = items.items,
    };
    
    // This should fail with NoSpaceLeft error when using the current implementation
    _ = try data.fromModel(allocator, model);
}
