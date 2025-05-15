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
pub const TransformerFn = *const fn(value_ptr: *const anyopaque, alloc: std.mem.Allocator) anyerror!*data.Value;

/// Type alias for the transformer map
pub const TransformerMap = std.StringHashMap(TransformerFn);

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
        var buf: [64]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{any}", .{model});
        try obj.put("value", data_obj.string(str));
        return obj;
    }
    
    // Process each field in the struct
    inline for (model_info.@"struct".fields) |field| {
        // For our initial implementation, just add all fields
        // We'll handle field filtering in a later version
        
        const field_value = @field(model, field.name);
        const field_type = @TypeOf(field_value);
        
        // Apply field renaming (simplified for now)
        const field_name = if (options.rename_map) |rename_map| blk: {
            if (rename_map.get(field.name)) |new_name| {
                break :blk new_name;
            }
            break :blk field.name;
        } else field.name;
        
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
                var buf: [64]u8 = undefined;
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
                    // For other types, use string representation
                    var buf: [64]u8 = undefined;
                    const str = try std.fmt.bufPrint(&buf, "{any}", .{val});
                    try obj.put(field_name, data_obj.string(str));
                }
            } else if (!options.skip_null) {
                // For simplicity, always add null fields as strings for now
                try obj.put(field_name, data_obj.string("null"));
            }
        } else {
            // Fall back to string representation for other types
            var buf: [64]u8 = undefined;
            const str = try std.fmt.bufPrint(&buf, "{any}", .{field_value});
            try obj.put(field_name, data_obj.string(str));
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
    // Create an empty array
    const array = try zmpl.Data.createArray(allocator);
    
    // Process each model
    for (models) |model| {
        const model_obj = try modelToDataWithOptions(allocator, model, options);
        try array.append(model_obj);
    }
    
    return array;
}