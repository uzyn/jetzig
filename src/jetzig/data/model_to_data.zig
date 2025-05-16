const std = @import("std");
const data = @import("../data.zig");
const zmpl = @import("zmpl").zmpl;

/// Enum for handling null values in different ways
pub const NullHandling = enum {
    /// Skip null fields entirely (default)
    skip,
    /// Convert null fields to empty strings/zero values depending on target type
    empty_or_zero,
    /// Convert null fields to literal "null" strings
    null_string,
    /// Set a custom value for null fields
    custom,
};

/// Options for controlling the model-to-data conversion process
pub const ModelToDataOptions = struct {
    /// How to handle null values
    null_handling: NullHandling = .skip,
    /// Custom value for nulls when using NullHandling.custom
    custom_null_value: ?[]const u8 = null,
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
pub const TransformerFn = *const fn(value_ptr: *const anyopaque, alloc: std.mem.Allocator) anyerror!*data.Value;

/// Type alias for the transformer map
pub const TransformerMap = std.StringHashMap(TransformerFn);

/// Helper function for compile-time checking if a field should be processed based on include/exclude options
fn shouldProcessField(comptime field_name: []const u8, options: ModelToDataOptions) bool {
    // Check exclusion first
    if (options.exclude) |exclude_list| {
        for (exclude_list) |excluded_field| {
            if (std.mem.eql(u8, field_name, excluded_field)) {
                return false; // Field is explicitly excluded
            }
        }
    }
    
    // If include list is specified, field must be in it
    if (options.include) |include_list| {
        for (include_list) |included_field| {
            if (std.mem.eql(u8, field_name, included_field)) {
                return true; // Field is explicitly included
            }
        }
        return false; // Not in include list
    }
    
    return true; // No inclusion/exclusion rules apply
}


/// Handle a null value based on the options and expected type
fn handleNullValue(
    allocator: std.mem.Allocator, 
    field_type_info: std.builtin.Type, 
    options: ModelToDataOptions
) ?*data.Value {
    var data_obj = data.Data.init(allocator);
    
    switch (options.null_handling) {
        .skip => return null, // Skip this field entirely
        .empty_or_zero => {
            // Use field_type_info.Optional.child to infer the expected type
            const child_type = field_type_info.@"optional".child;
            const child_type_info = @typeInfo(child_type);
            
            if (child_type == []const u8 or 
                child_type_info == .@"pointer" and child_type_info.@"pointer".child == u8) {
                // For string types, use empty string
                return data_obj.string("");
            } else if (child_type == i32 or child_type == i64 or 
                      child_type == u32 or child_type == u64 or 
                      child_type == comptime_int) {
                // For integer types, use 0
                return data_obj.integer(0);
            } else if (child_type == f32 or child_type == f64 or 
                      child_type == comptime_float) {
                // For float types, use 0.0
                return data_obj.float(0.0);
            } else if (child_type == bool) {
                // For boolean types, use false
                return data_obj.boolean(false);
            } else {
                // For other types, use empty string as fallback
                return data_obj.string("");
            }
        },
        .null_string => return data_obj.string("null"),
        .custom => {
            const val = options.custom_null_value orelse "null";
            return data_obj.string(val);
        },
    }
}

/// Convert a model struct to a data.Value object that can be used in templates
pub fn modelToData(
    allocator: std.mem.Allocator,
    model: anytype,
) !*data.Value {
    return modelToDataWithOptions(allocator, model, .{});
}

/// Convert a model struct to a data.Value object with specified options
pub fn modelToDataWithOptions(
    allocator: std.mem.Allocator,
    model: anytype,
    options: ModelToDataOptions,
) !*data.Value {
    var data_obj = data.Data.init(allocator);
    const obj = try zmpl.Data.createObject(allocator);
    
    const ModelType = @TypeOf(model);
    const model_info = @typeInfo(ModelType);
    
    if (model_info != .@"struct") {
        // Not a struct, just return a string representation
        // Use a dynamic buffer to prevent NoSpaceLeft errors with large data structures
        var list = std.ArrayList(u8).init(allocator);
        defer list.deinit(); // Safe because data_obj.string() makes a copy
        
        // Format to the list - this can handle arbitrarily large data
        try std.fmt.format(list.writer(), "{any}", .{model});
        
        // Create a string value from the list's contents
        // data_obj.string() makes its own copy of the string data
        try obj.put("value", data_obj.string(list.items));
        return obj;
    }
    
    // Process each field in the struct
    inline for (model_info.@"struct".fields) |field| {
        // Check if field should be included/excluded
        if (shouldProcessField(field.name, options)) {
            const field_value = @field(model, field.name);
            const field_type = @TypeOf(field_value);
            const field_type_info = @typeInfo(field_type);
            
            // Get final field name after possible renaming
            const field_name = if (options.rename_map) |rename_map| 
                rename_map.get(field.name) orelse field.name else field.name;
            
            // Apply custom transformers if available
            var applied_transformer = false;
            if (options.transformers) |transformer_map| {
                if (transformer_map.get(field.name)) |transformer| {
                    const value_ptr = @as(*const anyopaque, @ptrCast(&field_value));
                    const transformed = try transformer(value_ptr, allocator);
                    try obj.put(field_name, transformed);
                    applied_transformer = true;
                }
            }
            
            if (!applied_transformer) {
                // Handle special cases
                
                // Special handling for array pointers - convert to array format
                if (field_type_info == .@"pointer") {
                    const ptr_info = field_type_info.@"pointer";
                    
                    if (ptr_info.size == .slice and ptr_info.child == u8) {
                        // String case - handle normally
                        try obj.put(field_name, data_obj.string(field_value));
                    } else {
                        const child_type = ptr_info.child;
                        const child_info = @typeInfo(child_type);
                        
                        if (child_info == .@"array") {
                            // It's an array pointer - create an array
                            const array = try zmpl.Data.createArray(allocator);
                            
                            // Get element type
                            const element_type = child_info.@"array".child;
                            const element_type_info = @typeInfo(element_type);
                            
                            if (element_type_info == .@"struct") {
                                // Array of structs - convert each struct
                                for (field_value) |item| {
                                    const item_obj = try modelToDataWithOptions(allocator, item, options);
                                    try array.append(item_obj);
                                }
                            } else {
                                // Array of primitives - convert each item
                                for (field_value) |item| {
                                    const ItemType = @TypeOf(item);
                                    
                                    if (ItemType == []const u8) {
                                        try array.append(data_obj.string(item));
                                    } else if (ItemType == bool) {
                                        try array.append(data_obj.boolean(item));
                                    } else if (ItemType == i64 or ItemType == i32 or 
                                              ItemType == u64 or ItemType == u32 or
                                              ItemType == comptime_int) {
                                        try array.append(data_obj.integer(@as(i64, @intCast(item))));
                                    } else if (ItemType == f64 or ItemType == f32 or
                                              ItemType == comptime_float) {
                                        try array.append(data_obj.float(@as(f64, @floatCast(item))));
                                    } else {
                                        // For other types, convert to string using dynamic buffer
                                        // Use dynamic buffer to avoid NoSpaceLeft errors with large data
                                        var list = std.ArrayList(u8).init(allocator);
                                        defer list.deinit(); // Safe because data_obj.string() makes a copy
                                        
                                        // Format to the list
                                        try std.fmt.format(list.writer(), "{any}", .{item});
                                        
                                        // Append the string value
                                        try array.append(data_obj.string(list.items));
                                    }
                                }
                            }
                            
                            try obj.put(field_name, array);
                            continue;
                        }
                        
                        // Default - convert to string using dynamic buffer
                        // Use dynamic buffer to avoid NoSpaceLeft errors with large data
                        var list = std.ArrayList(u8).init(allocator);
                        defer list.deinit(); // Safe because data_obj.string() makes a copy
                        
                        // Format to the list
                        try std.fmt.format(list.writer(), "{any}", .{field_value});
                        
                        // Add the string value
                        try obj.put(field_name, data_obj.string(list.items));
                    }
                } else {
                    // Handle other types normally
                    switch (field_type_info) {
                        .@"bool" => try obj.put(field_name, data_obj.boolean(field_value)),
                        .@"int", .@"comptime_int" => 
                            try obj.put(field_name, data_obj.integer(@as(i64, @intCast(field_value)))),
                        .@"float", .@"comptime_float" => 
                            try obj.put(field_name, data_obj.float(@as(f64, @floatCast(field_value)))),
                        .@"optional" => {
                            if (field_value) |val| {
                                const val_type = @TypeOf(val);
                                const inner_type_info = @typeInfo(val_type);
                                
                                if (val_type == bool) {
                                    try obj.put(field_name, data_obj.boolean(val));
                                } else if (val_type == i32 or val_type == i64 or val_type == u32 or 
                                        val_type == u64 or val_type == comptime_int) {
                                    try obj.put(field_name, data_obj.integer(@as(i64, @intCast(val))));
                                } else if (val_type == f32 or val_type == f64) {
                                    try obj.put(field_name, data_obj.float(@as(f64, @floatCast(val))));
                                } else if (val_type == []const u8) {
                                    try obj.put(field_name, data_obj.string(val));
                                } else if (inner_type_info == .@"struct") {
                                    const nested = try modelToDataWithOptions(allocator, val, options);
                                    try obj.put(field_name, nested);
                                } else {
                                    // Use dynamic buffer to avoid NoSpaceLeft errors with large data
                                    var list = std.ArrayList(u8).init(allocator);
                                    defer list.deinit(); // Safe because data_obj.string() makes a copy
                                    
                                    // Format to the list
                                    try std.fmt.format(list.writer(), "{any}", .{val});
                                    
                                    // Add the string value
                                    try obj.put(field_name, data_obj.string(list.items));
                                }
                            } else {
                                if (handleNullValue(allocator, field_type_info, options)) |value| {
                                    try obj.put(field_name, value);
                                }
                            }
                        },
                        .@"struct" => {
                            const nested = try modelToDataWithOptions(allocator, field_value, options);
                            try obj.put(field_name, nested);
                        },
                        else => {
                            // Use dynamic buffer to avoid NoSpaceLeft errors with large data
                            var list = std.ArrayList(u8).init(allocator);
                            defer list.deinit(); // Safe because data_obj.string() makes a copy
                            
                            // Format to the list
                            try std.fmt.format(list.writer(), "{any}", .{field_value});
                            
                            // Add the string value
                            try obj.put(field_name, data_obj.string(list.items));
                        },
                    }
                }
            }
        }
    }
    
    return obj;
}

/// Convert an array of model structs or primitives to a data.Array
pub fn modelsToArray(
    allocator: std.mem.Allocator,
    models: anytype,
    options: ModelToDataOptions,
) !*data.Value {
    const array = try zmpl.Data.createArray(allocator);
    var data_obj = data.Data.init(allocator);
    
    const ModelType = @TypeOf(models);
    const model_info = @typeInfo(ModelType);
    
    // Ensure this is a pointer to an array
    if (model_info != .@"pointer") return array;
    
    const child_type = model_info.@"pointer".child;
    const child_info = @typeInfo(child_type);
    
    if (child_info != .@"array") return array;
    
    // Get element type
    const element_type = child_info.@"array".child;
    const element_type_info = @typeInfo(element_type);
    
    // Different handling based on element type
    if (element_type_info == .@"struct") {
        // Process each model struct
        for (models) |model| {
            const model_obj = try modelToDataWithOptions(allocator, model, options);
            try array.append(model_obj);
        }
    } else if (element_type == []const u8) {
        // Special handling for string arrays
        for (models) |item| {
            try array.append(data_obj.string(item));
        }
    } else {
        // Handle other primitive types
        for (models) |item| {
            const ItemType = @TypeOf(item);
            
            if (ItemType == bool) {
                try array.append(data_obj.boolean(item));
            } else if (ItemType == i64 or ItemType == i32 or 
                      ItemType == u64 or ItemType == u32 or
                      ItemType == comptime_int) {
                try array.append(data_obj.integer(@as(i64, @intCast(item))));
            } else if (ItemType == f64 or ItemType == f32 or
                      ItemType == comptime_float) {
                try array.append(data_obj.float(@as(f64, @floatCast(item))));
            } else {
                // For other types, convert to string
                var buf: [512]u8 = undefined;
                const str = try std.fmt.bufPrint(&buf, "{any}", .{item});
                try array.append(data_obj.string(str));
            }
        }
    }
    
    return array;
}

/// Automatically convert a model or array of models to a data.Value with options
/// This function automatically detects whether to use modelToData or modelsToArray
/// based on the type of the input model:
///
/// - For regular struct objects, it converts the struct to a data.Object
/// - For arrays of primitives (strings, booleans, numbers), it converts them to a data.Array of primitive values
/// - For arrays of structs, it converts them to a data.Array of data.Objects
///
/// This allows for seamless handling of nested data structures without having
/// to explicitly choose between modelToData and modelsToArray.
///
/// Note: This is exported as the public API function fromModelWithOptions()
pub fn fromModel(
    allocator: std.mem.Allocator,
    model: anytype,
    options: ModelToDataOptions,
) !*data.Value {
    const ModelType = @TypeOf(model);
    const model_info = @typeInfo(ModelType);
    
    // Check if this is a pointer to an array
    if (model_info == .@"pointer") {
        const child_type = model_info.@"pointer".child;
        const child_info = @typeInfo(child_type);
        
        if (child_info == .@"array") {
            // It's an array, use modelsToArray
            return modelsToArray(allocator, model, options);
        }
    }
    
    // It's not an array, use modelToDataWithOptions
    return modelToDataWithOptions(allocator, model, options);
}

/// Shorthand for fromModel with default options
/// Calls fromModel with empty options (default behavior)
/// Note: This is exported as the primary public API function fromModel()
pub fn fromModelWithDefaults(
    allocator: std.mem.Allocator,
    model: anytype,
) !*data.Value {
    return fromModel(allocator, model, .{});
}