const std = @import("std");
const testing = std.testing;
const data = @import("../data.zig");
const zmpl = @import("zmpl").zmpl;

// This file contains minimal tests for the model-to-data conversion functions
// More comprehensive tests will be implemented in model_to_data_test.zig
// after these basic tests pass

// Simple model structure
const SimpleModel = struct {
    id: i64,
    name: []const u8,
    optional_field: ?[]const u8 = null,
};

// Test our fromModel function returns an object
test "fromModel function" {
    // Use an arena for all allocations in this test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const model = SimpleModel{
        .id = 999,
        .name = "Test Model",
    };
    
    // Call the implementation
    const result = try data.fromModel(allocator, model);
    // No need to call deinit() since the arena will clean up
    
    // Should return an object
    try testing.expect(@as(data.ValueType, result.*) == .object);
}

// Test our fromModelWithOptions function
test "fromModelWithOptions function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const model = SimpleModel{
        .id = 999,
        .name = "Test Model",
    };
    
    // Call the implementation with empty options
    const result = try data.fromModelWithOptions(allocator, model, .{});
    
    // Verify it returns an object
    try testing.expect(@as(data.ValueType, result.*) == .object);
}

// Test different null handling options
test "fromModelWithOptions null handling" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const model = SimpleModel{
        .id = 999,
        .name = "Test Model",
        .optional_field = null,
    };
    
    // Test with skip null (default)
    {
        const result = try data.fromModelWithOptions(allocator, model, .{});
        try testing.expect(@as(data.ValueType, result.*) == .object);
        const obj = result.object;
        try testing.expect(obj.get("optional_field") == null);
    }
    
    // Test with empty string for nulls
    {
        const result = try data.fromModelWithOptions(allocator, model, .{
            .null_handling = .empty_or_zero,
        });
        try testing.expect(@as(data.ValueType, result.*) == .object);
        const obj = result.object;
        try testing.expectEqualStrings("", obj.get("optional_field").?.string.value);
    }
    
    // Test with "null" string for nulls
    {
        const result = try data.fromModelWithOptions(allocator, model, .{
            .null_handling = .null_string,
        });
        try testing.expect(@as(data.ValueType, result.*) == .object);
        const obj = result.object;
        try testing.expectEqualStrings("null", obj.get("optional_field").?.string.value);
    }
    
    // Test with custom value for nulls
    {
        const result = try data.fromModelWithOptions(allocator, model, .{
            .null_handling = .custom,
            .custom_null_value = "N/A",
        });
        try testing.expect(@as(data.ValueType, result.*) == .object);
        const obj = result.object;
        try testing.expectEqualStrings("N/A", obj.get("optional_field").?.string.value);
    }
}

// Test fromModel with arrays
test "fromModel with arrays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const models = [_]SimpleModel{
        .{ .id = 1, .name = "One" },
        .{ .id = 2, .name = "Two" },
    };
    
    // Call the implementation with an array
    const result = try data.fromModel(allocator, &models);
    
    // Verify it returns an array
    try testing.expect(@as(data.ValueType, result.*) == .array);
}