const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");
const data = jetzig.data;
const zmpl = @import("zmpl").zmpl;

// Test case to demonstrate the NoSpaceLeft error with a large string
test "fromModel with large string causes NoSpaceLeft error" {
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
    
    // This should fail with NoSpaceLeft error
    _ = try data.fromModel(allocator, model);
}

// Test case to demonstrate the NoSpaceLeft error with a complex non-struct type
test "fromModel with complex non-struct type causes NoSpaceLeft error" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a complex type that will produce a large string when formatted
    const ComplexError = error{
        VeryLongErrorNameToTriggerBufferOverflowWhenFormattedAsAStringRepresentationWithLotsOfDetails,
    };
    
    // Create a model with the complex error type
    const ErrorModel = struct {
        error_value: ComplexError,
    };
    
    // Create the model with the complex error
    const model = ErrorModel{
        .error_value = ComplexError.VeryLongErrorNameToTriggerBufferOverflowWhenFormattedAsAStringRepresentationWithLotsOfDetails,
    };
    
    // This should fail with NoSpaceLeft error
    _ = try data.fromModel(allocator, model);
}

// Test case to demonstrate the NoSpaceLeft error with deeply nested structures
test "fromModel with deeply nested structure causes NoSpaceLeft error" {
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
    
    // This should fail with NoSpaceLeft error when trying to format the non-struct type
    _ = try data.fromModel(allocator, model);
}

// Test case to demonstrate the NoSpaceLeft error with a large array of values
test "fromModel with large array causes NoSpaceLeft error" {
    // Use an arena allocator to avoid memory management issues
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a model with a large array
    const LargeArrayModel = struct {
        items: []const []const u8,
    };
    
    // Create an array with many entries that together exceed the buffer size
    var items = std.ArrayList([]const u8).init(allocator);
    defer items.deinit();
    
    // Add enough entries to exceed the buffer
    for (0..30) |i| {
        const item = try std.fmt.allocPrint(allocator, "This is item number {d} with some extra text to make it longer", .{i});
        try items.append(item);
    }
    
    const model = LargeArrayModel{
        .items = items.items,
    };
    
    // This should fail with NoSpaceLeft error
    _ = try data.fromModel(allocator, model);
}