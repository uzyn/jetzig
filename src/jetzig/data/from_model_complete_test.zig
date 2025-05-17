const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");
const test_helpers = @import("test_helpers.zig");

test "fromModel with basic types" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    // Test integer
    {
        const value = try jetzig.data.fromModel(request, @as(u64, 42));
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .integer);
        try testing.expectEqual(@as(i64, 42), value.integer.value);
    }
    
    // Test float
    {
        const value = try jetzig.data.fromModel(request, @as(f64, 3.14));
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .float);
        // Float equality can have precision issues, so we just check it's approximately 3.14
        try testing.expect(value.float.value >= 3.13 and value.float.value <= 3.15);
    }
    
    // Test boolean
    {
        const value = try jetzig.data.fromModel(request, true);
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .boolean);
        try testing.expectEqual(true, value.boolean.value);
    }
    
    // Test string
    {
        const value = try jetzig.data.fromModel(request, "Test String");
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .string);
        try testing.expectEqualStrings("Test String", value.string.value);
    }
}

test "fromModel with struct containing basic fields" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    const User = struct {
        id: u64,
        name: []const u8,
        active: bool,
        rating: f32,
    };
    
    const user = User{
        .id = 42,
        .name = "John Doe",
        .active = true,
        .rating = 4.5,
    };
    
    // Create a data object from the user struct
    const value = try jetzig.data.fromModel(request, user);
    
    // Verify it's an object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    
    // Verify basic fields
    try testing.expectEqual(@as(i64, 42), value.object.get("id").?.integer.value);
    try testing.expectEqualStrings("John Doe", value.object.get("name").?.string.value);
    try testing.expectEqual(true, value.object.get("active").?.boolean.value);
    try testing.expectEqual(@as(f128, 4.5), value.object.get("rating").?.float.value);
}

test "fromModel with nested structs" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    const Address = struct {
        street: []const u8,
        city: []const u8,
        zip: []const u8,
    };
    
    const User = struct {
        id: u64,
        name: []const u8,
        address: Address,
    };
    
    const user = User{
        .id = 42,
        .name = "John Doe",
        .address = .{
            .street = "123 Main St",
            .city = "Anytown",
            .zip = "12345",
        },
    };
    
    // Create a data object from the user struct
    const value = try jetzig.data.fromModel(request, user);
    
    // Verify it's an object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    
    // Verify basic fields
    try testing.expectEqual(@as(i64, 42), value.object.get("id").?.integer.value);
    try testing.expectEqualStrings("John Doe", value.object.get("name").?.string.value);
    
    // Verify nested struct
    const address = value.object.get("address").?;
    try testing.expect(@as(jetzig.data.ValueType, address.*) == .object);
    try testing.expectEqualStrings("123 Main St", address.object.get("street").?.string.value);
    try testing.expectEqualStrings("Anytown", address.object.get("city").?.string.value);
    try testing.expectEqualStrings("12345", address.object.get("zip").?.string.value);
}

test "fromModel with arrays and slices" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    // Array of integers
    {
        const numbers = [_]i32{ 1, 2, 3, 4, 5 };
        const value = try jetzig.data.fromModel(request, &numbers);
        
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .array);
        try testing.expectEqual(@as(usize, 5), value.array.array.items.len);
        
        for (0..5) |i| {
            const num = value.array.array.items[i];
            try testing.expect(@as(jetzig.data.ValueType, num.*) == .integer);
            try testing.expectEqual(@as(i64, @intCast(i + 1)), num.integer.value);
        }
    }
    
    // Slice of strings
    {
        const tags = [_][]const u8{ "one", "two", "three" };
        const value = try jetzig.data.fromModel(request, &tags);
        
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .array);
        try testing.expectEqual(@as(usize, 3), value.array.array.items.len);
        
        try testing.expectEqualStrings("one", value.array.array.items[0].string.value);
        try testing.expectEqualStrings("two", value.array.array.items[1].string.value);
        try testing.expectEqualStrings("three", value.array.array.items[2].string.value);
    }
}

test "fromModel with array of structs" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    const Item = struct {
        id: u32,
        name: []const u8,
    };
    
    const items = [_]Item{
        .{ .id = 1, .name = "Item 1" },
        .{ .id = 2, .name = "Item 2" },
        .{ .id = 3, .name = "Item 3" },
    };
    
    const value = try jetzig.data.fromModel(request, &items);
    
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .array);
    try testing.expectEqual(@as(usize, 3), value.array.array.items.len);
    
    // Verify first item
    const item1 = value.array.array.items[0];
    try testing.expect(@as(jetzig.data.ValueType, item1.*) == .object);
    try testing.expectEqual(@as(i64, 1), item1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("Item 1", item1.object.get("name").?.string.value);
    
    // Verify second item
    const item2 = value.array.array.items[1];
    try testing.expect(@as(jetzig.data.ValueType, item2.*) == .object);
    try testing.expectEqual(@as(i64, 2), item2.object.get("id").?.integer.value);
    try testing.expectEqualStrings("Item 2", item2.object.get("name").?.string.value);
}

test "fromModel with complex nested structure" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    const Address = struct {
        street: []const u8,
        city: []const u8,
    };
    
    const Comment = struct {
        id: u32,
        text: []const u8,
    };
    
    const Post = struct {
        id: u64,
        title: []const u8,
        comments: []const Comment,
    };
    
    const User = struct {
        id: u64,
        name: []const u8,
        address: Address,
        posts: []const Post,
        tags: []const []const u8,
    };
    
    // Create comments
    const comments1 = [_]Comment{
        .{ .id = 1, .text = "Great post!" },
        .{ .id = 2, .text = "Thanks" },
    };
    
    const comments2 = [_]Comment{
        .{ .id = 3, .text = "Interesting" },
    };
    
    // Create posts
    const posts = [_]Post{
        .{ .id = 101, .title = "First Post", .comments = &comments1 },
        .{ .id = 102, .title = "Second Post", .comments = &comments2 },
    };
    
    // Create tags
    const tags = [_][]const u8{ "developer", "zig", "web" };
    
    // Create user with nested structures
    const user = User{
        .id = 42,
        .name = "John Doe",
        .address = .{
            .street = "123 Main St",
            .city = "Anytown",
        },
        .posts = &posts,
        .tags = &tags,
    };
    
    // Convert to template data
    const value = try jetzig.data.fromModel(request, user);
    
    // Verify top level object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    try testing.expectEqual(@as(i64, 42), value.object.get("id").?.integer.value);
    try testing.expectEqualStrings("John Doe", value.object.get("name").?.string.value);
    
    // Verify address
    const address = value.object.get("address").?;
    try testing.expect(@as(jetzig.data.ValueType, address.*) == .object);
    try testing.expectEqualStrings("123 Main St", address.object.get("street").?.string.value);
    try testing.expectEqualStrings("Anytown", address.object.get("city").?.string.value);
    
    // Verify tags
    const tag_array = value.object.get("tags").?;
    try testing.expect(@as(jetzig.data.ValueType, tag_array.*) == .array);
    try testing.expectEqual(@as(usize, 3), tag_array.array.array.items.len);
    try testing.expectEqualStrings("developer", tag_array.array.array.items[0].string.value);
    try testing.expectEqualStrings("zig", tag_array.array.array.items[1].string.value);
    try testing.expectEqualStrings("web", tag_array.array.array.items[2].string.value);
    
    // Verify posts
    const post_array = value.object.get("posts").?;
    try testing.expect(@as(jetzig.data.ValueType, post_array.*) == .array);
    try testing.expectEqual(@as(usize, 2), post_array.array.array.items.len);
    
    // Verify first post
    const post1 = post_array.array.array.items[0];
    try testing.expect(@as(jetzig.data.ValueType, post1.*) == .object);
    try testing.expectEqual(@as(i64, 101), post1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("First Post", post1.object.get("title").?.string.value);
    
    // Verify comments on first post
    const comments1_array = post1.object.get("comments").?;
    try testing.expect(@as(jetzig.data.ValueType, comments1_array.*) == .array);
    try testing.expectEqual(@as(usize, 2), comments1_array.array.array.items.len);
    try testing.expectEqual(@as(i64, 1), comments1_array.array.array.items[0].object.get("id").?.integer.value);
    try testing.expectEqualStrings("Great post!", comments1_array.array.array.items[0].object.get("text").?.string.value);
    
    // Verify second post
    const post2 = post_array.array.array.items[1];
    try testing.expect(@as(jetzig.data.ValueType, post2.*) == .object);
    try testing.expectEqual(@as(i64, 102), post2.object.get("id").?.integer.value);
    try testing.expectEqualStrings("Second Post", post2.object.get("title").?.string.value);
    
    // Verify comments on second post
    const comments2_array = post2.object.get("comments").?;
    try testing.expect(@as(jetzig.data.ValueType, comments2_array.*) == .array);
    try testing.expectEqual(@as(usize, 1), comments2_array.array.array.items.len);
    try testing.expectEqual(@as(i64, 3), comments2_array.array.array.items[0].object.get("id").?.integer.value);
    try testing.expectEqualStrings("Interesting", comments2_array.array.array.items[0].object.get("text").?.string.value);
}

test "fromModel with enum" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    const Color = enum {
        red,
        green,
        blue,
    };
    
    const value = try jetzig.data.fromModel(request, Color.green);
    
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .string);
    try testing.expectEqualStrings("green", value.string.value);
}

test "fromModel with optional fields" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var request = try test_helpers.createMockRequest(allocator);
    defer allocator.destroy(request);
    
    const User = struct {
        id: u64,
        name: []const u8,
        email: ?[]const u8,
    };
    
    // Test with present optional
    {
        const user = User{
            .id = 42,
            .name = "John Doe",
            .email = "john@example.com",
        };
        
        const value = try jetzig.data.fromModel(request, user);
        
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
        try testing.expectEqual(@as(i64, 42), value.object.get("id").?.integer.value);
        try testing.expectEqualStrings("John Doe", value.object.get("name").?.string.value);
        
        const email = value.object.get("email").?;
        try testing.expect(@as(jetzig.data.ValueType, email.*) == .string);
        try testing.expectEqualStrings("john@example.com", email.string.value);
    }
    
    // Test with null optional
    {
        const user = User{
            .id = 43,
            .name = "Jane Doe",
            .email = null,
        };
        
        const value = try jetzig.data.fromModel(request, user);
        
        try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
        try testing.expectEqual(@as(i64, 43), value.object.get("id").?.integer.value);
        try testing.expectEqualStrings("Jane Doe", value.object.get("name").?.string.value);
        
        const email = value.object.get("email").?;
        try testing.expect(@as(jetzig.data.ValueType, email.*) == .null);
    }
}