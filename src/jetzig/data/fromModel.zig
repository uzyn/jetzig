const std = @import("std");
const jetzig = @import("../..");

/// Converts a Zig model (struct or array) to a Data value that can be used in templates
/// Uses the direct data creation approach which is proven to work reliably
pub fn fromModel(allocator: std.mem.Allocator, value: anytype) !*jetzig.data.Value {
    const T = @TypeOf(value);
    const data_obj = jetzig.data.Data.init(allocator);
    
    return switch (@typeInfo(T)) {
        .struct => try structToValue(allocator, value, data_obj),
        .pointer => |ptr_info| switch (ptr_info.size) {
            .One => switch (@typeInfo(ptr_info.child)) {
                .struct => try structToValue(allocator, value.*, data_obj),
                else => @compileError("Unsupported pointer type: " ++ @typeName(T)),
            },
            .Slice => try arrayToValue(allocator, value, data_obj),
            else => @compileError("Unsupported pointer type: " ++ @typeName(T)),
        },
        .array => try arrayToValue(allocator, &value, data_obj),
        .int, .float, .bool => blk: {
            const val = switch (@typeInfo(T)) {
                .int => data_obj.integer(value),
                .float => data_obj.float(value),
                .bool => data_obj.boolean(value),
                else => unreachable,
            };
            break :blk val;
        },
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    };
}

/// Helper function to convert a struct to a Value
fn structToValue(allocator: std.mem.Allocator, value: anytype, data_obj: jetzig.data.Data) !*jetzig.data.Value {
    const T = @TypeOf(value);
    var root = try data_obj.root(.object);
    
    inline for (std.meta.fields(T)) |field| {
        const field_value = @field(value, field.name);
        const field_type = @TypeOf(field_value);
        
        switch (@typeInfo(field_type)) {
            .struct => {
                const nested = try structToValue(allocator, field_value, data_obj);
                try root.put(field.name, nested);
            },
            .pointer => |ptr_info| switch (ptr_info.size) {
                .One => switch (@typeInfo(ptr_info.child)) {
                    .struct => {
                        const nested = try structToValue(allocator, field_value.*, data_obj);
                        try root.put(field.name, nested);
                    },
                    else => @compileError("Unsupported pointer field type: " ++ @typeName(field_type)),
                },
                .Slice => switch (ptr_info.child) {
                    u8 => try root.put(field.name, data_obj.string(field_value)),
                    else => {
                        const array_val = try arrayToValue(allocator, field_value, data_obj);
                        try root.put(field.name, array_val);
                    },
                },
                else => @compileError("Unsupported pointer field type: " ++ @typeName(field_type)),
            },
            .array => |array_info| switch (array_info.child) {
                u8 => try root.put(field.name, data_obj.string(&field_value)),
                else => {
                    const array_val = try arrayToValue(allocator, &field_value, data_obj);
                    try root.put(field.name, array_val);
                },
            },
            .int => try root.put(field.name, data_obj.integer(field_value)),
            .float => try root.put(field.name, data_obj.float(field_value)),
            .bool => try root.put(field.name, data_obj.boolean(field_value)),
            .enum_ => try root.put(field.name, data_obj.string(@tagName(field_value))),
            else => @compileError("Unsupported field type: " ++ @typeName(field_type)),
        }
    }
    
    return root.value.?;
}

/// Helper function to convert an array to a Value
fn arrayToValue(allocator: std.mem.Allocator, value: anytype, data_obj: jetzig.data.Data) !*jetzig.data.Value {
    const T = @TypeOf(value);
    const ptr_info = @typeInfo(T).pointer;
    
    var array = try jetzig.data.Data.createArray(allocator);
    
    switch (ptr_info.size) {
        .Slice => {
            const slice = value;
            const child_type = ptr_info.child;
            
            switch (@typeInfo(child_type)) {
                .struct => {
                    for (slice) |item| {
                        const item_val = try structToValue(allocator, item, data_obj);
                        try array.append(item_val);
                    }
                },
                .pointer => |item_ptr_info| switch (item_ptr_info.size) {
                    .Slice => switch (item_ptr_info.child) {
                        u8 => {
                            for (slice) |str| {
                                try array.append(data_obj.string(str));
                            }
                        },
                        else => @compileError("Unsupported nested array type: " ++ @typeName(child_type)),
                    },
                    else => @compileError("Unsupported array item type: " ++ @typeName(child_type)),
                },
                .int => {
                    for (slice) |item| {
                        try array.append(data_obj.integer(item));
                    }
                },
                .float => {
                    for (slice) |item| {
                        try array.append(data_obj.float(item));
                    }
                },
                .bool => {
                    for (slice) |item| {
                        try array.append(data_obj.boolean(item));
                    }
                },
                else => @compileError("Unsupported array item type: " ++ @typeName(child_type)),
            }
        },
        .One => {
            const child_type = ptr_info.child;
            
            switch (@typeInfo(child_type)) {
                .array => |array_info| {
                    const array_ptr = value;
                    switch (@typeInfo(array_info.child)) {
                        .struct => {
                            for (array_ptr.*) |item| {
                                const item_val = try structToValue(allocator, item, data_obj);
                                try array.append(item_val);
                            }
                        },
                        .int => {
                            for (array_ptr.*) |item| {
                                try array.append(data_obj.integer(item));
                            }
                        },
                        .float => {
                            for (array_ptr.*) |item| {
                                try array.append(data_obj.float(item));
                            }
                        },
                        .bool => {
                            for (array_ptr.*) |item| {
                                try array.append(data_obj.boolean(item));
                            }
                        },
                        .pointer => |item_ptr_info| switch (item_ptr_info.size) {
                            .Slice => switch (item_ptr_info.child) {
                                u8 => {
                                    for (array_ptr.*) |str| {
                                        try array.append(data_obj.string(str));
                                    }
                                },
                                else => @compileError("Unsupported nested array type: " ++ @typeName(array_info.child)),
                            },
                            else => @compileError("Unsupported array item type: " ++ @typeName(array_info.child)),
                        },
                        else => @compileError("Unsupported array item type: " ++ @typeName(array_info.child)),
                    }
                },
                else => @compileError("Unsupported array container type: " ++ @typeName(child_type)),
            }
        },
        else => @compileError("Unsupported array type: " ++ @typeName(T)),
    }
    
    return &array.value;
}