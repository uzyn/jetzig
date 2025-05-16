const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");

test "fromModel with HashMap" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a string HashMap
    var string_map = std.StringHashMap([]const u8).init(allocator);
    defer string_map.deinit();
    
    try string_map.put("name", "John Doe");
    try string_map.put("email", "john@example.com");
    try string_map.put("role", "admin");
    
    // Convert to template data
    const value = try jetzig.data.fromModel(allocator, string_map);
    
    // Verify it's an object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    
    // Verify fields
    try testing.expectEqualStrings("John Doe", value.object.get("name").?.string.value);
    try testing.expectEqualStrings("john@example.com", value.object.get("email").?.string.value);
    try testing.expectEqualStrings("admin", value.object.get("role").?.string.value);
}

test "fromModel with HashMap of complex values" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const User = struct {
        id: u32,
        name: []const u8,
        active: bool,
    };
    
    // Create a HashMap with struct values
    var user_map = std.StringHashMap(User).init(allocator);
    defer user_map.deinit();
    
    try user_map.put("user1", .{ .id = 1, .name = "John", .active = true });
    try user_map.put("user2", .{ .id = 2, .name = "Jane", .active = false });
    
    // Convert to template data
    const value = try jetzig.data.fromModel(allocator, user_map);
    
    // Verify it's an object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    
    // Verify user1
    const user1 = value.object.get("user1").?;
    try testing.expect(@as(jetzig.data.ValueType, user1.*) == .object);
    try testing.expectEqual(@as(i64, 1), user1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("John", user1.object.get("name").?.string.value);
    try testing.expectEqual(true, user1.object.get("active").?.boolean.value);
    
    // Verify user2
    const user2 = value.object.get("user2").?;
    try testing.expect(@as(jetzig.data.ValueType, user2.*) == .object);
    try testing.expectEqual(@as(i64, 2), user2.object.get("id").?.integer.value);
    try testing.expectEqualStrings("Jane", user2.object.get("name").?.string.value);
    try testing.expectEqual(false, user2.object.get("active").?.boolean.value);
}

test "fromModel with nested HashMap" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create nested HashMaps
    var roles_map = std.StringHashMap(bool).init(allocator);
    defer roles_map.deinit();
    try roles_map.put("admin", true);
    try roles_map.put("editor", true);
    try roles_map.put("viewer", false);
    
    var user_data = std.StringHashMap(std.StringHashMap(bool)).init(allocator);
    defer user_data.deinit();
    try user_data.put("roles", roles_map);
    
    // Convert to template data
    const value = try jetzig.data.fromModel(allocator, user_data);
    
    // Verify it's an object
    try testing.expect(@as(jetzig.data.ValueType, value.*) == .object);
    
    // Verify nested structure
    const roles = value.object.get("roles").?;
    try testing.expect(@as(jetzig.data.ValueType, roles.*) == .object);
    
    // Verify role values
    try testing.expectEqual(true, roles.object.get("admin").?.boolean.value);
    try testing.expectEqual(true, roles.object.get("editor").?.boolean.value);
    try testing.expectEqual(false, roles.object.get("viewer").?.boolean.value);
}