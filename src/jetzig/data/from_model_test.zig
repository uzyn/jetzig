const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");
const fromModel = @import("fromModel.zig").fromModel;

test "fromModel with nested struct" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const User = struct {
        id: u64,
        name: []const u8,
        email: []const u8,
        active: bool,
        preferences: struct {
            theme: []const u8,
            notifications: bool,
        },
        favorite_numbers: [3]u32,
        tags: []const []const u8,
    };
    
    const user = User{
        .id = 42,
        .name = "John Doe",
        .email = "john@example.com",
        .active = true,
        .preferences = .{
            .theme = "dark",
            .notifications = false,
        },
        .favorite_numbers = .{ 7, 42, 100 },
        .tags = &.{ "developer", "admin" },
    };
    
    // Create a data object from the user struct
    const value = try fromModel(allocator, user);
    
    // Verify it's an object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    
    // Verify basic fields
    try testing.expectEqual(@as(i64, 42), value.object.get("id").?.integer.value);
    try testing.expectEqualStrings("John Doe", value.object.get("name").?.string.value);
    try testing.expectEqualStrings("john@example.com", value.object.get("email").?.string.value);
    try testing.expectEqual(true, value.object.get("active").?.boolean.value);
    
    // Verify nested struct
    const prefs = value.object.get("preferences").?;
    try testing.expect(@as(jetzig.data.ValueType, prefs.*) == .object);
    try testing.expectEqualStrings("dark", prefs.object.get("theme").?.string.value);
    try testing.expectEqual(false, prefs.object.get("notifications").?.boolean.value);
    
    // Verify array of integers
    const numbers = value.object.get("favorite_numbers").?;
    try testing.expect(@as(jetzig.data.ValueType, numbers.*) == .array);
    try testing.expectEqual(@as(usize, 3), numbers.array.array.items.len);
    try testing.expectEqual(@as(i64, 7), numbers.array.array.items[0].integer.value);
    try testing.expectEqual(@as(i64, 42), numbers.array.array.items[1].integer.value);
    try testing.expectEqual(@as(i64, 100), numbers.array.array.items[2].integer.value);
    
    // Verify array of strings
    const tags = value.object.get("tags").?;
    try testing.expect(@as(jetzig.data.ValueType, tags.*) == .array);
    try testing.expectEqual(@as(usize, 2), tags.array.array.items.len);
    try testing.expectEqualStrings("developer", tags.array.array.items[0].string.value);
    try testing.expectEqualStrings("admin", tags.array.array.items[1].string.value);
}

test "fromModel with array of structs" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const Post = struct {
        id: u64,
        title: []const u8,
        content: []const u8,
    };
    
    const posts = [_]Post{
        .{
            .id = 1,
            .title = "First Post",
            .content = "Hello World!",
        },
        .{
            .id = 2,
            .title = "Second Post",
            .content = "Another post",
        },
    };
    
    // Create a data object from the array of posts
    const value = try fromModel(allocator, &posts);
    
    // Verify it's an array
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .array);
    try testing.expectEqual(@as(usize, 2), value.array.array.items.len);
    
    // Verify first post
    const post1 = value.array.array.items[0];
    try testing.expect(@as(jetzig.data.ValueType, post1.*) == .object);
    try testing.expectEqual(@as(i64, 1), post1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("First Post", post1.object.get("title").?.string.value);
    try testing.expectEqualStrings("Hello World!", post1.object.get("content").?.string.value);
    
    // Verify second post
    const post2 = value.array.array.items[1];
    try testing.expect(@as(jetzig.data.ValueType, post2.*) == .object);
    try testing.expectEqual(@as(i64, 2), post2.object.get("id").?.integer.value);
    try testing.expectEqualStrings("Second Post", post2.object.get("title").?.string.value);
    try testing.expectEqualStrings("Another post", post2.object.get("content").?.string.value);
}

test "fromModel with slice of integers" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const numbers = [_]u32{ 1, 2, 3, 4, 5 };
    const numbers_slice: []const u32 = &numbers;
    
    // Create a data object from the array
    const value = try fromModel(allocator, numbers_slice);
    
    // Verify it's an array
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .array);
    try testing.expectEqual(@as(usize, 5), value.array.array.items.len);
    
    // Verify values
    for (0..5) |i| {
        const num = value.array.array.items[i];
        try testing.expect(@as(jetzig.data.ValueType, num.*) == .integer);
        try testing.expectEqual(@as(i64, i + 1), num.integer.value);
    }
}