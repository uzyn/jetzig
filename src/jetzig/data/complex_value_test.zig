const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");
const data = jetzig.data;
const zmpl = @import("zmpl").zmpl;

// Test structures for complex nested data
const Favorite = struct {
    id: u64,
    name: []const u8,
    rating: u8,
};

const User = struct {
    id: u64,
    name: []const u8,
    email: ?[]const u8 = null,
    favorites: []const Favorite,
    tags: []const []const u8,
    settings: UserSettings,
    metadata: std.StringHashMap([]const u8),
};

const UserSettings = struct {
    theme: []const u8,
    notifications: bool,
    preferences: std.StringHashMap([]const u8),
};

// Test zmplValue with deeply nested structure
test "zmplValue with complex nested structure" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create metadata
    var metadata = std.StringHashMap([]const u8).init(allocator);
    try metadata.put("role", "admin");
    try metadata.put("status", "active");
    
    // Create preferences
    var preferences = std.StringHashMap([]const u8).init(allocator);
    try preferences.put("language", "en");
    try preferences.put("timezone", "UTC");
    
    // Create a complex user object with nested structures
    const user = User{
        .id = 42,
        .name = "John Doe",
        .email = "john@example.com",
        .favorites = &[_]Favorite{
            .{ .id = 1, .name = "First Favorite", .rating = 5 },
            .{ .id = 2, .name = "Second Favorite", .rating = 4 },
        },
        .tags = &[_][]const u8{ "tag1", "tag2", "tag3" },
        .settings = .{
            .theme = "dark",
            .notifications = true,
            .preferences = preferences,
        },
        .metadata = metadata,
    };
    
    // Convert the complex structure using zmplValue
    const result = try data.Data.zmplValue(user, allocator);
    
    // Verify it's an object
    try testing.expect(@as(data.ValueType, result.*) == .object);
    
    // Check top-level fields
    try testing.expectEqual(@as(i64, 42), result.object.get("id").?.integer.value);
    try testing.expectEqualStrings("John Doe", result.object.get("name").?.string.value);
    try testing.expectEqualStrings("john@example.com", result.object.get("email").?.string.value);
    
    // Check favorites array
    const favorites = result.object.get("favorites").?;
    try testing.expect(@as(data.ValueType, favorites.*) == .array);
    try testing.expectEqual(@as(usize, 2), favorites.array.array.items.len);
    
    // Check first favorite
    const favorite1 = favorites.array.array.items[0];
    try testing.expect(@as(data.ValueType, favorite1.*) == .object);
    try testing.expectEqual(@as(i64, 1), favorite1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("First Favorite", favorite1.object.get("name").?.string.value);
    try testing.expectEqual(@as(i64, 5), favorite1.object.get("rating").?.integer.value);
    
    // Check tags
    const tags = result.object.get("tags").?;
    try testing.expect(@as(data.ValueType, tags.*) == .array);
    try testing.expectEqual(@as(usize, 3), tags.array.array.items.len);
    try testing.expectEqualStrings("tag1", tags.array.array.items[0].string.value);
    try testing.expectEqualStrings("tag2", tags.array.array.items[1].string.value);
    try testing.expectEqualStrings("tag3", tags.array.array.items[2].string.value);
    
    // Check settings
    const settings = result.object.get("settings").?;
    try testing.expect(@as(data.ValueType, settings.*) == .object);
    try testing.expectEqualStrings("dark", settings.object.get("theme").?.string.value);
    try testing.expect(settings.object.get("notifications").?.boolean.value);
    
    // Check preferences in settings
    const preferences_obj = settings.object.get("preferences").?;
    try testing.expect(@as(data.ValueType, preferences_obj.*) == .object);
    try testing.expectEqualStrings("en", preferences_obj.object.get("language").?.string.value);
    try testing.expectEqualStrings("UTC", preferences_obj.object.get("timezone").?.string.value);
    
    // Check metadata
    const metadata_obj = result.object.get("metadata").?;
    try testing.expect(@as(data.ValueType, metadata_obj.*) == .object);
    try testing.expectEqualStrings("admin", metadata_obj.object.get("role").?.string.value);
    try testing.expectEqualStrings("active", metadata_obj.object.get("status").?.string.value);
}

// Test array of mixed types
test "zmplValue with array of mixed types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create an array of different types using an ArrayList
    var mixed_array = std.ArrayList(*data.Value).init(allocator);
    try mixed_array.append(try data.Data.zmplValue("string value", allocator));
    try mixed_array.append(try data.Data.zmplValue(42, allocator));
    try mixed_array.append(try data.Data.zmplValue(true, allocator));
    
    // Create a nested object
    var obj = try zmpl.Data.createObject(allocator);
    try obj.put("key", "value");
    try mixed_array.append(obj);
    
    // Create a nested array
    var arr = try zmpl.Data.createArray(allocator);
    try arr.append(1);
    try arr.append(2);
    try mixed_array.append(arr);
    
    // Convert the mixed array
    const result = try data.Data.zmplValue(mixed_array.items, allocator);
    
    // Verify it's an array
    try testing.expect(@as(data.ValueType, result.*) == .array);
    try testing.expectEqual(@as(usize, 5), result.array.array.items.len);
    
    // Check array elements
    try testing.expectEqualStrings("string value", result.array.array.items[0].string.value);
    try testing.expectEqual(@as(i64, 42), result.array.array.items[1].integer.value);
    try testing.expect(result.array.array.items[2].boolean.value);
    
    // Check nested object
    const nested_obj = result.array.array.items[3];
    try testing.expect(@as(data.ValueType, nested_obj.*) == .object);
    try testing.expectEqualStrings("value", nested_obj.object.get("key").?.string.value);
    
    // Check nested array
    const nested_arr = result.array.array.items[4];
    try testing.expect(@as(data.ValueType, nested_arr.*) == .array);
    try testing.expectEqual(@as(usize, 2), nested_arr.array.array.items.len);
    try testing.expectEqual(@as(i64, 1), nested_arr.array.array.items[0].integer.value);
    try testing.expectEqual(@as(i64, 2), nested_arr.array.array.items[1].integer.value);
}

// Test integration with request.data().set()
test "direct object setting with complex data" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create metadata
    var metadata = std.StringHashMap([]const u8).init(allocator);
    try metadata.put("role", "admin");
    
    // Create a user with nested data
    const user = User{
        .id = 42,
        .name = "John Doe",
        .favorites = &[_]Favorite{
            .{ .id = 1, .name = "First Favorite", .rating = 5 },
        },
        .tags = &[_][]const u8{ "tag1", "tag2" },
        .settings = .{
            .theme = "dark",
            .notifications = true,
            .preferences = std.StringHashMap([]const u8).init(allocator),
        },
        .metadata = metadata,
    };
    
    // Create a data object (simulating request.data(.object))
    var data_obj = data.Data.init(allocator);
    var root = try data_obj.root(.object);
    
    // Set the user directly
    try root.put("user", user);
    
    // Verify the user data was properly converted
    const user_obj = root.object.get("user").?;
    try testing.expect(@as(data.ValueType, user_obj.*) == .object);
    try testing.expectEqual(@as(i64, 42), user_obj.object.get("id").?.integer.value);
    
    // Verify the favorites array
    const favorites = user_obj.object.get("favorites").?;
    try testing.expect(@as(data.ValueType, favorites.*) == .array);
    try testing.expectEqual(@as(usize, 1), favorites.array.array.items.len);
    
    // Verify the tags array
    const tags = user_obj.object.get("tags").?;
    try testing.expect(@as(data.ValueType, tags.*) == .array);
    try testing.expectEqual(@as(usize, 2), tags.array.array.items.len);
}

// Test nested arrays
test "zmplValue with nested arrays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const Matrix = struct {
        name: []const u8,
        rows: []const []const i32,
    };
    
    const matrix = Matrix{
        .name = "Test Matrix",
        .rows = &[_][]const i32{
            &[_]i32{ 1, 2, 3 },
            &[_]i32{ 4, 5, 6 },
            &[_]i32{ 7, 8, 9 },
        },
    };
    
    const result = try data.Data.zmplValue(matrix, allocator);
    
    // Check matrix structure
    try testing.expect(@as(data.ValueType, result.*) == .object);
    try testing.expectEqualStrings("Test Matrix", result.object.get("name").?.string.value);
    
    const rows = result.object.get("rows").?;
    try testing.expect(@as(data.ValueType, rows.*) == .array);
    try testing.expectEqual(@as(usize, 3), rows.array.array.items.len);
    
    // Check each row
    for (0..3) |i| {
        const row = rows.array.array.items[i];
        try testing.expect(@as(data.ValueType, row.*) == .array);
        try testing.expectEqual(@as(usize, 3), row.array.array.items.len);
        
        for (0..3) |j| {
            const expected = @as(i64, @intCast(i * 3 + j + 1));
            try testing.expectEqual(expected, row.array.array.items[j].integer.value);
        }
    }
}

// Test with structs containing other structs with arrays
test "zmplValue with structs containing arrays of structs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const Comment = struct {
        id: u32,
        text: []const u8,
    };
    
    const Post = struct {
        id: u32,
        title: []const u8,
        comments: []const Comment,
    };
    
    const Blog = struct {
        name: []const u8,
        posts: []const Post,
    };
    
    const blog = Blog{
        .name = "Test Blog",
        .posts = &[_]Post{
            .{
                .id = 1,
                .title = "First Post",
                .comments = &[_]Comment{
                    .{ .id = 101, .text = "Great post!" },
                    .{ .id = 102, .text = "I learned a lot" },
                },
            },
            .{
                .id = 2,
                .title = "Second Post",
                .comments = &[_]Comment{
                    .{ .id = 201, .text = "Interesting" },
                },
            },
        },
    };
    
    const result = try data.Data.zmplValue(blog, allocator);
    
    // Check blog structure
    try testing.expect(@as(data.ValueType, result.*) == .object);
    try testing.expectEqualStrings("Test Blog", result.object.get("name").?.string.value);
    
    const posts = result.object.get("posts").?;
    try testing.expect(@as(data.ValueType, posts.*) == .array);
    try testing.expectEqual(@as(usize, 2), posts.array.array.items.len);
    
    // Check first post
    const post1 = posts.array.array.items[0];
    try testing.expect(@as(data.ValueType, post1.*) == .object);
    try testing.expectEqual(@as(i64, 1), post1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("First Post", post1.object.get("title").?.string.value);
    
    const comments1 = post1.object.get("comments").?;
    try testing.expect(@as(data.ValueType, comments1.*) == .array);
    try testing.expectEqual(@as(usize, 2), comments1.array.array.items.len);
    
    // Check first comment of first post
    const comment1 = comments1.array.array.items[0];
    try testing.expect(@as(data.ValueType, comment1.*) == .object);
    try testing.expectEqual(@as(i64, 101), comment1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("Great post!", comment1.object.get("text").?.string.value);
    
    // Check second post
    const post2 = posts.array.array.items[1];
    try testing.expect(@as(data.ValueType, post2.*) == .object);
    try testing.expectEqual(@as(i64, 2), post2.object.get("id").?.integer.value);
    try testing.expectEqualStrings("Second Post", post2.object.get("title").?.string.value);
    
    const comments2 = post2.object.get("comments").?;
    try testing.expect(@as(data.ValueType, comments2.*) == .array);
    try testing.expectEqual(@as(usize, 1), comments2.array.array.items.len);
}