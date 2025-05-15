const std = @import("std");
const data = @import("../data.zig");
const zmpl = @import("zmpl").zmpl;

/// Options for controlling the model-to-data conversion process
pub const ModelToDataOptions = struct {
    /// Skip null or undefined fields
    skip_null: bool = true,

    /// Custom field transformations (field name → function)
    transformers: ?TransformerMap = null,

    /// Field renaming (original → new)
    rename_map: ?std.StringHashMap([]const u8) = null,

    /// Fields to include (if null, include all)
    include: ?[]const []const u8 = null,

    /// Fields to exclude
    exclude: ?[]const []const u8 = null,
};

/// Type alias for the transformer function
/// Uses an opaque pointer for the value to avoid anytype compilation issues
pub const TransformerFn = *const fn(value_ptr: *const anyopaque, alloc: std.mem.Allocator) anyerror!*data.Value;

/// Type alias for the transformer map
pub const TransformerMap = std.StringHashMap(TransformerFn);

/// Convert a model struct to a data.Value object that can be used in templates
/// This is a placeholder to make tests compile - actual implementation will come later
pub fn modelToData(
    allocator: std.mem.Allocator,
    model: anytype,
) !*data.Value {
    // Placeholder implementation 
    // The caller is responsible for calling deinit() on the result
    _ = model;
    
    // Create an empty object
    const obj = try zmpl.Data.createObject(allocator);
    
    // This is a stub implementation that will be replaced with real code later
    // It should return a valid object that can be examined in tests
    
    return obj;
}

/// Convert a model struct to a data.Value object with specified options
/// This is a placeholder to make tests compile - actual implementation will come later
pub fn modelToDataWithOptions(
    allocator: std.mem.Allocator,
    model: anytype,
    options: ModelToDataOptions,
) !*data.Value {
    // Placeholder implementation
    // The caller is responsible for calling deinit() on the result
    _ = model;
    _ = options;
    
    // Create an empty object
    const obj = try zmpl.Data.createObject(allocator);
    
    // This is a stub implementation that will be replaced with real code later
    // It should return a valid object that can be examined in tests
    
    return obj;
}

/// Convert an array of model structs to a data.Array
/// This is a placeholder to make tests compile - actual implementation will come later
pub fn modelsToArray(
    allocator: std.mem.Allocator,
    models: anytype,
    options: ModelToDataOptions,
) !*data.Value {
    // Placeholder implementation
    // The caller is responsible for calling deinit() on the result
    _ = models;
    _ = options;
    
    // Create an empty array
    const array = try zmpl.Data.createArray(allocator);
    
    // This is a stub implementation that will be replaced with real code later
    // It should return a valid array that can be examined in tests
    
    return array;
}