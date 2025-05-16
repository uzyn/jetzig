const std = @import("std");
const testing = std.testing;
const data = @import("../data.zig");
const zmpl = @import("zmpl").zmpl;

// Helper function to create test values
fn createTestValue(allocator: std.mem.Allocator) !*data.Value {
    var obj = try zmpl.Data.createObject(allocator);
    var data_obj = data.Data.init(allocator);
    
    try obj.put("id", data_obj.integer(1));
    try obj.put("name", data_obj.string("Test User"));
    try obj.put("email", data_obj.string("test@example.com"));
    try obj.put("is_admin", data_obj.boolean(true));
    
    return obj;
}

// Example model structs for testing
const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
    is_admin: bool,
    last_login: ?i64,
    metadata: ?Metadata,
};

const Metadata = struct {
    login_count: u32,
    preferences: Preferences,
};

const Preferences = struct {
    theme: []const u8,
    notifications_enabled: bool,
};

const Post = struct {
    id: i64,
    title: []const u8,
    content: []const u8,
    author_id: i64,
    tags: []const []const u8,
    created_at: i64,
};

test "modelToData basic conversion" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Setup test model
    const user = User{
        .id = 1,
        .name = "Test User",
        .email = "test@example.com",
        .is_admin = true,
        .last_login = 1683912345,
        .metadata = null,
    };

    // Use the new null_handling options to handle null values as strings
    const result = try data.modelToDataWithOptions(allocator, user, .{
        .null_handling = .null_string,
    });

    // Verify basic properties
    try testing.expect(@as(data.ValueType, result.*) == .object);
    
    const obj = result.object;
    try testing.expectEqual(@as(i64, 1), obj.get("id").?.integer.value);
    try testing.expectEqualStrings("Test User", obj.get("name").?.string.value);
    try testing.expectEqualStrings("test@example.com", obj.get("email").?.string.value);
    try testing.expect(obj.get("is_admin").?.boolean.value);
    try testing.expectEqual(@as(i64, 1683912345), obj.get("last_login").?.integer.value);
    try testing.expectEqualStrings("null", obj.get("metadata").?.string.value);
}

test "modelToData with nested structs" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const preferences = Preferences{
        .theme = "dark",
        .notifications_enabled = true,
    };
    
    const metadata = Metadata{
        .login_count = 42,
        .preferences = preferences,
    };
    
    const user = User{
        .id = 2,
        .name = "Advanced User",
        .email = "advanced@example.com",
        .is_admin = false,
        .last_login = 1683912345,
        .metadata = metadata,
    };

    // Use our full implementation with null handling
    const result = try data.modelToDataWithOptions(allocator, user, .{
        .null_handling = .null_string,
    });

    // Test nested struct conversion
    try testing.expect(@as(data.ValueType, result.*) == .object);
    
    const obj = result.object;
    const meta_obj = obj.get("metadata").?.object;
    
    try testing.expectEqual(@as(u32, 42), @as(u32, @intCast(meta_obj.get("login_count").?.integer.value)));
    
    const prefs_obj = meta_obj.get("preferences").?.object;
    try testing.expectEqualStrings("dark", prefs_obj.get("theme").?.string.value);
    try testing.expect(prefs_obj.get("notifications_enabled").?.boolean.value);
}

test "modelToData with options" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const user = User{
        .id = 3,
        .name = "Options User",
        .email = "options@example.com",
        .is_admin = true,
        .last_login = 1683912345,
        .metadata = null,
    };
    
    // Test with field exclusion
    {
        const result = try data.modelToDataWithOptions(
            allocator, 
            user, 
            .{ 
                .exclude = &[_][]const u8{"last_login", "metadata"},
                .null_handling = .null_string,
            }
        );
        
        try testing.expect(@as(data.ValueType, result.*) == .object);
        
        const obj = result.object;
        try testing.expect(obj.get("id") != null);
        try testing.expect(obj.get("last_login") == null);
        try testing.expect(obj.get("metadata") == null);
    }
    
    // Test with field inclusion
    {
        const result = try data.modelToDataWithOptions(
            allocator, 
            user, 
            .{ 
                .include = &[_][]const u8{"id", "name"},
                .null_handling = .null_string,
            }
        );
        
        try testing.expect(@as(data.ValueType, result.*) == .object);
        
        const obj = result.object;
        try testing.expect(obj.get("id") != null);
        try testing.expect(obj.get("name") != null);
        try testing.expect(obj.get("email") == null);
        try testing.expect(obj.get("is_admin") == null);
    }
    
    // Test with field renaming
    {
        var rename_map = std.StringHashMap([]const u8).init(allocator);
        defer rename_map.deinit();
        
        try rename_map.put("email", "contact_email");
        try rename_map.put("is_admin", "admin_status");
        
        const result = try data.modelToDataWithOptions(
            allocator, 
            user, 
            .{ 
                .rename_map = rename_map,
                .null_handling = .null_string,
            }
        );
        
        try testing.expect(@as(data.ValueType, result.*) == .object);
        
        const obj = result.object;
        try testing.expect(obj.get("email") == null);
        try testing.expect(obj.get("is_admin") == null);
        try testing.expect(obj.get("contact_email") != null);
        try testing.expect(obj.get("admin_status") != null);
    }
}

test "modelsToArray conversion" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var users = [_]User{
        User{
            .id = 1,
            .name = "User One",
            .email = "one@example.com",
            .is_admin = false,
            .last_login = null,
            .metadata = null,
        },
        User{
            .id = 2,
            .name = "User Two",
            .email = "two@example.com",
            .is_admin = true,
            .last_login = 1683912345,
            .metadata = null,
        },
    };

    // Use our implementation with null handling
    const result = try data.modelsToArray(allocator, &users, .{
        .null_handling = .null_string,
    });
    
    try testing.expect(@as(data.ValueType, result.*) == .array);
    
    const arr = result.array;
    try testing.expectEqual(@as(usize, 2), arr.count());
    
    // Verify first user
    const user1 = arr.get(0).?.object;
    try testing.expectEqual(@as(i64, 1), user1.get("id").?.integer.value);
    try testing.expectEqualStrings("User One", user1.get("name").?.string.value);
    
    // Verify second user
    const user2 = arr.get(1).?.object;
    try testing.expectEqual(@as(i64, 2), user2.get("id").?.integer.value);
    try testing.expectEqualStrings("User Two", user2.get("name").?.string.value);
}

test "modelToData with custom transformers" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const post = Post{
        .id = 101,
        .title = "Test Post",
        .content = "This is test content",
        .author_id = 1,
        .tags = &[_][]const u8{"test", "example"},
        .created_at = 1683912345,
    };

    // Setup transformer map
    var transformers = data.model_to_data.TransformerMap.init(allocator);
    
    // Add a custom date transformer
    const dateTransformer = struct {
        fn transform(value_ptr: *const anyopaque, alloc: std.mem.Allocator) anyerror!*data.Value {
            // We don't use the input value for this test
            _ = value_ptr;
            
            // Format timestamp as an ISO date (simplified for test)
            var buf: [32]u8 = undefined;
            const date_str = try std.fmt.bufPrint(&buf, "2023-01-01T21:00:00Z", .{});
            var data_obj = data.Data.init(alloc);
            return data_obj.string(date_str);
        }
    }.transform;

    try transformers.put("created_at", dateTransformer);
    
    // Now try with our implementation of transformers
    const result = try data.modelToDataWithOptions(
        allocator,
        post,
        .{ 
            .transformers = transformers,
            .null_handling = .null_string,
        }
    );
    
    try testing.expect(@as(data.ValueType, result.*) == .object);
    
    const obj = result.object;
    try testing.expectEqualStrings("2023-01-01T21:00:00Z", obj.get("created_at").?.string.value);
}