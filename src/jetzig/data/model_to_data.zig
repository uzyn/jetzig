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
    /// This is a string value that will be interpreted based on context
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
fn shouldProcessFieldComptime(comptime field_name: []const u8, options: ModelToDataOptions) bool {
    // Create helper functions for runtime string comparison
    const fieldIsExcluded = struct {
        fn check(name: []const u8, exclude_list: []const []const u8) bool {
            for (exclude_list) |excluded_field| {
                if (std.mem.eql(u8, name, excluded_field)) {
                    return true; // Field is explicitly excluded
                }
            }
            return false; // Field is not excluded
        }
    }.check;
    
    const fieldIsIncluded = struct {
        fn check(name: []const u8, include_list: []const []const u8) bool {
            for (include_list) |included_field| {
                if (std.mem.eql(u8, name, included_field)) {
                    return true; // Field is explicitly included
                }
            }
            return false; // Field is not included
        }
    }.check;
    
    // Check exclusion first
    if (options.exclude) |exclude_list| {
        if (fieldIsExcluded(field_name, exclude_list)) {
            return false; // Field is explicitly excluded
        }
    }
    
    // If include list is specified, field must be in it
    if (options.include) |include_list| {
        return fieldIsIncluded(field_name, include_list); // Only include if in the list
    }
    
    return true; // No include list specified, include by default
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
    // Create data context for the template
    var data_obj = data.Data.init(allocator);
    
    // Create the result object
    const obj = try zmpl.Data.createObject(allocator);
    
    // Use reflection to process struct fields
    const ModelType = @TypeOf(model);
    const model_info = @typeInfo(ModelType);
    
    if (model_info != .@"struct") {
        // Not a struct, just return a string representation
        var buf: [512]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{any}", .{model});
        try obj.put("value", data_obj.string(str));
        return obj;
    }
    
    // Process each field in the struct
    inline for (model_info.@"struct".fields) |field| {
        // Check if field should be included/excluded (at compile-time)
        const should_process = shouldProcessFieldComptime(field.name, options);
        
        // Skip this field if it should not be processed
        if (should_process) {
            const field_value = @field(model, field.name);
            const field_type = @TypeOf(field_value);
            
            // Apply field renaming
            const field_name = if (options.rename_map) |rename_map| blk: {
                if (rename_map.get(field.name)) |new_name| {
                    break :blk new_name;
                }
                break :blk field.name;
            } else field.name;
            
            // Apply custom transformers if available
            var applied_transformer = false;
            if (options.transformers) |transformer_map| {
                if (transformer_map.get(field.name)) |transformer| {
                    // Custom transformation - convert the field value to the expected type
                    const value_ptr = @as(*const anyopaque, @ptrCast(&field_value));
                    const transformed = try transformer(value_ptr, allocator);
                    try obj.put(field_name, transformed);
                    applied_transformer = true;
                }
            }
            
            if (!applied_transformer) {
                // Process field value based on type
                const field_type_info = @typeInfo(field_type);
                
                if (field_type_info == .@"bool") {
                    try obj.put(field_name, data_obj.boolean(field_value));
                } else if (field_type_info == .@"int" or field_type_info == .@"comptime_int") {
                    try obj.put(field_name, data_obj.integer(@as(i64, @intCast(field_value))));
                } else if (field_type_info == .@"float" or field_type_info == .@"comptime_float") {
                    try obj.put(field_name, data_obj.float(@as(f64, @floatCast(field_value))));
                } else if (field_type_info == .@"pointer") {
                    const ptr_info = field_type_info.@"pointer";
                    if (ptr_info.size == .slice and ptr_info.child == u8) {
                        try obj.put(field_name, data_obj.string(field_value));
                    } else {
                        // For other pointer types, use string representation
                        var buf: [512]u8 = undefined;
                        const str = try std.fmt.bufPrint(&buf, "{any}", .{field_value});
                        try obj.put(field_name, data_obj.string(str));
                    }
                } else if (field_type_info == .@"optional") {
                    if (field_value) |val| {
                        // Handle unwrapped value based on its type
                        const val_type = @TypeOf(val);
                        
                        if (val_type == bool) {
                            try obj.put(field_name, data_obj.boolean(val));
                        } else if (val_type == i32 or val_type == i64 or val_type == u32 or 
                                 val_type == u64 or val_type == comptime_int) {
                            try obj.put(field_name, data_obj.integer(@as(i64, @intCast(val))));
                        } else if (val_type == f32 or val_type == f64) {
                            try obj.put(field_name, data_obj.float(@as(f64, @floatCast(val))));
                        } else if (val_type == []const u8) {
                            try obj.put(field_name, data_obj.string(val));
                        } else {
                            // Check if it's a struct and handle recursively
                            const inner_type_info = @typeInfo(val_type);
                            if (inner_type_info == .@"struct") {
                                // Recursively convert nested struct
                                const nested = try modelToDataWithOptions(allocator, val, options);
                                try obj.put(field_name, nested);
                            } else {
                                // For other types, use string representation
                                var buf: [512]u8 = undefined;
                                const str = try std.fmt.bufPrint(&buf, "{any}", .{val});
                                try obj.put(field_name, data_obj.string(str));
                            }
                        }
                    } else {
                        // Handle null values based on options
                        switch (options.null_handling) {
                            .skip => {}, // Skip this field entirely
                            .empty_or_zero => {
                                // Check expected return type based on field name or other context
                                // Use field_type_info.Optional.child to infer the expected type
                                const child_type = field_type_info.@"optional".child;
                                const child_type_info = @typeInfo(child_type);
                                
                                if (child_type == []const u8 or 
                                    child_type_info == .@"pointer" and child_type_info.@"pointer".child == u8) {
                                    // For string types, use empty string
                                    try obj.put(field_name, data_obj.string(""));
                                } else if (child_type == i32 or child_type == i64 or 
                                          child_type == u32 or child_type == u64 or 
                                          child_type == comptime_int) {
                                    // For integer types, use 0
                                    try obj.put(field_name, data_obj.integer(0));
                                } else if (child_type == f32 or child_type == f64 or 
                                          child_type == comptime_float) {
                                    // For float types, use 0.0
                                    try obj.put(field_name, data_obj.float(0.0));
                                } else if (child_type == bool) {
                                    // For boolean types, use false
                                    try obj.put(field_name, data_obj.boolean(false));
                                } else {
                                    // For other types, use empty string as fallback
                                    try obj.put(field_name, data_obj.string(""));
                                }
                            },
                            .null_string => {
                                try obj.put(field_name, data_obj.string("null"));
                            },
                            .custom => {
                                const val = options.custom_null_value orelse "null";
                                try obj.put(field_name, data_obj.string(val));
                            },
                        }
                    }
                } else if (field_type_info == .@"struct") {
                    // Recursively convert nested struct
                    const nested = try modelToDataWithOptions(allocator, field_value, options);
                    try obj.put(field_name, nested);
                } else {
                    // Fall back to string representation for other types
                    var buf: [512]u8 = undefined;
                    const str = try std.fmt.bufPrint(&buf, "{any}", .{field_value});
                    try obj.put(field_name, data_obj.string(str));
                }
            }
        }
    }
    
    return obj;
}

/// Convert an array of model structs to a data.Array
pub fn modelsToArray(
    allocator: std.mem.Allocator,
    models: anytype,
    options: ModelToDataOptions,
) !*data.Value {
    const array = try zmpl.Data.createArray(allocator);
    
    // Process each model
    for (models) |model| {
        const model_obj = try modelToDataWithOptions(allocator, model, options);
        try array.append(model_obj);
    }
    
    return array;
}