const std = @import("std");

const zmpl = @import("zmpl").zmpl;
const jetcommon = @import("jetcommon");

pub const Writer = zmpl.Data.Writer;
pub const Data = zmpl.Data;

/// Converts Zig data types (structs, arrays, primitives) to template data
/// This function supports:
/// - Basic types (integers, floats, booleans, strings)
/// - Nested structs
/// - Arrays and slices of basic types
/// - Arrays and slices of structs
/// - Optional fields (null is converted to a null value)
/// - Enums (converted to strings using @tagName)
pub fn fromModel(value: anytype, allocator: std.mem.Allocator) !*Value {
    var data = Data.init(allocator);
    
    return try fromModelInternal(value, &data, allocator);
}

/// Internal recursive implementation of fromModel
fn fromModelInternal(value: anytype, data: *Data, allocator: std.mem.Allocator) !*Value {
    // Handle different types
    switch (@typeInfo(@TypeOf(value))) {
        // Basic types
        .@"int", .@"comptime_int" => return data.integer(value),
        .@"float", .@"comptime_float" => return data.float(value),
        .@"bool" => return data.boolean(value),
        
        // String types ([]const u8 or []u8)
        .@"pointer" => |ptr_info| {
            if (ptr_info.size == .slice) {
                if (ptr_info.child == u8) {
                    // String case
                    return data.string(value);
                } else {
                    // Slice of other types (including structs)
                    return try sliceToValue(value, data, allocator);
                }
            } else if (ptr_info.size == .one) {
                // Handle pointer to struct
                return try fromModelInternal(value.*, data, allocator);
            } else {
                @compileError("Unsupported pointer type: " ++ @typeName(@TypeOf(value)));
            }
        },
        
        // Arrays
        .@"array" => |array_info| {
            if (array_info.child == u8) {
                // Handle arrays of u8 as strings
                return data.string(&value);
            } else {
                // Handle arrays of other types
                return try arrayToValue(&value, data, allocator);
            }
        },
        
        // Structs
        .@"struct" => return try structToValueRecursively(value, data, allocator),
        
        // Optionals
        .@"optional" => {
            if (value) |unwrapped| {
                return try fromModelInternal(unwrapped, data, allocator);
            } else {
                return zmpl.Data._null(allocator);
            }
        },
        
        // Enums
        .@"enum", .@"enum_literal" => return data.string(@tagName(value)),
        
        else => @compileError("Unsupported type: " ++ @typeName(@TypeOf(value))),
    }
}

/// Converts a struct to a Value
fn structToValueRecursively(value: anytype, data: *Data, allocator: std.mem.Allocator) !*Value {
    var obj = try Data.createObject(allocator);
    
    inline for (std.meta.fields(@TypeOf(value))) |field| {
        const field_value = @field(value, field.name);
        const field_data = try fromModelInternal(field_value, data, allocator);
        try obj.put(field.name, field_data);
    }
    
    return obj;
}

/// Converts a slice to a Value
fn sliceToValue(slice: anytype, data: *Data, allocator: std.mem.Allocator) !*Value {
    var array = try Data.createArray(allocator);
    
    for (slice) |item| {
        const item_value = try fromModelInternal(item, data, allocator);
        try array.append(item_value);
    }
    
    return array;
}

/// Converts an array to a Value
fn arrayToValue(array_ptr: anytype, data: *Data, allocator: std.mem.Allocator) !*Value {
    var array = try Data.createArray(allocator);
    
    for (array_ptr.*) |item| {
        const item_value = try fromModelInternal(item, data, allocator);
        try array.append(item_value);
    }
    
    return array;
}
pub const Value = zmpl.Data.Value;
pub const NullType = zmpl.Data.NullType;
pub const Float = zmpl.Data.Float;
pub const Integer = zmpl.Data.Integer;
pub const Boolean = zmpl.Data.Boolean;
pub const String = zmpl.Data.String;
pub const Object = zmpl.Data.Object;
pub const Array = zmpl.Data.Array;
pub const ValueType = zmpl.Data.ValueType;

/// Enhanced zmplValue function that supports complex data structures
pub fn zmplValue(value: anytype, alloc: std.mem.Allocator) !*Value {
    const is_enum_literal = comptime @TypeOf(value) == @TypeOf(.enum_literal);
    if (comptime is_enum_literal and value == .object) {
        return try Data.createObject(alloc);
    } else if (comptime is_enum_literal and value == .array) {
        return try Data.createArray(alloc);
    } else if (comptime is_enum_literal) {
        @compileError(
            "Enum literal must be `.object` or `.array`, found `" ++ @tagName(value) ++ "`",
        );
    }

    if (@TypeOf(value) == jetcommon.types.DateTime) {
        const val = try alloc.create(Value);
        val.* = .{ .datetime = .{ .value = value, .allocator = alloc } };
        return val;
    }

    const val = switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => Value{ .integer = .{ .value = value, .allocator = alloc } },
        .float, .comptime_float => Value{ .float = .{ .value = value, .allocator = alloc } },
        .bool => Value{ .boolean = .{ .value = value, .allocator = alloc } },
        .null => Value{ .null = NullType{ .allocator = alloc } },
        .@"enum" => Value{ .string = .{ .value = @tagName(value), .allocator = alloc } },
        .pointer => |info| switch (@typeInfo(info.child)) {
            .@"union" => {
                switch (info.child) {
                    Value => return value,
                    else => @compileError("Unsupported pointer/union: " ++ @typeName(@TypeOf(value))),
                }
            },
            .@"struct" => blk: {
                if (info.size == .slice and info.child == u8) {
                    // String case
                    // Create a copy of the string to ensure it's valid
                    const string_copy = alloc.dupe(u8, value) catch |err| return err;
                    break :blk Value{ .string = .{ .value = string_copy, .allocator = alloc } };
                } else if (info.size == .slice) {
                    // Slice of complex values
                    var inner_array = Array.init(alloc);
                    for (value) |item| {
                        try inner_array.append(try zmplValue(item, alloc));
                    }
                    break :blk Value{ .array = inner_array };
                } else if (info.size == .one) {
                    // Single-item struct pointer
                    break :blk try structToValue(value.*, alloc);
                } else {
                    // Handle multi-item or many-item pointers
                    var buf = std.ArrayList(u8).init(alloc);
                    defer buf.deinit();
                    try std.fmt.format(buf.writer(), "{any}", .{value});
                    break :blk Value{ .string = .{ .value = buf.items, .allocator = alloc } };
                }
            },
            .array => blk: {
                // Handle array pointers (like matrix rows)
                var inner_array = Array.init(alloc);
                for (value) |item| {
                    try inner_array.append(try zmplValue(item, alloc));
                }
                break :blk Value{ .array = inner_array };
            },
            else => blk: {
                if (info.child == *Value) {
                    // Array of value pointers
                    var inner_array = Array.init(alloc);
                    for (value) |item| {
                        try inner_array.append(item);
                    }
                    break :blk Value{ .array = inner_array };
                } else if (info.child == []const u8) {
                    // Array of strings
                    var inner_array = Array.init(alloc);
                    for (value) |item| {
                        try inner_array.append(try zmplValue(item, alloc));
                    }
                    break :blk Value{ .array = inner_array };
                } else {
                    // Stringify unknown types
                    var buf = std.ArrayList(u8).init(alloc);
                    defer buf.deinit();
                    try std.fmt.format(buf.writer(), "{any}", .{value});
                    
                    break :blk Value{ .string = .{ .value = buf.items, .allocator = alloc } };
                }
            },
        },
        .array => |info| switch (info.child) {
            u8 => Value{ .string = .{ .value = value, .allocator = alloc } },
            else => blk: {
                // Generic array handler
                var inner_array = Array.init(alloc);
                for (value) |item| {
                    try inner_array.append(try zmplValue(item, alloc));
                }
                break :blk Value{ .array = inner_array };
            },
        },
        .optional => blk: {
            if (value) |is_value| {
                return zmplValue(is_value, alloc);
            } else {
                break :blk Value{ .null = NullType{ .allocator = alloc } };
            }
        },
        .error_union => return if (value) |capture|
            zmplValue(capture, alloc)
        else |err|
            err,
        .@"struct" => try structToValue(value, alloc),
        // Handle StringHashMap type - check if the value has an iterator method
        else => if (@hasDecl(@TypeOf(value), "iterator") and 
                    @hasDecl(@TypeOf(value.iterator()), "next") and 
                    @hasField(@TypeOf(value.iterator().next()), "key_ptr")) blk: {
            var obj = Object.init(alloc);
            
            var it = value.iterator();
            while (it.next()) |entry| {
                const key = if (@TypeOf(entry.key_ptr.*) == []const u8) entry.key_ptr.* else blk2: {
                    var buf: [256]u8 = undefined;
                    break :blk2 try std.fmt.bufPrintZ(&buf, "{any}", .{entry.key_ptr.*});
                };
                try obj.put(key, try zmplValue(entry.value_ptr.*, alloc));
            }
            
            break :blk Value{ .object = obj };
        } else @compileError("Unsupported type: " ++ @typeName(@TypeOf(value))),
    };
    const copy = try alloc.create(Value);
    copy.* = val;
    return copy;
}

/// Improved structToValue implementation for complex nested structures
fn structToValue(value: anytype, alloc: std.mem.Allocator) !Value {
    var obj = Object.init(alloc);
    inline for (std.meta.fields(@TypeOf(value))) |field| {
        // Allow serializing structs that may have some extra type fields (e.g. JetQuery results).
        if (comptime field.type == type) continue;

        const field_value = @field(value, field.name);
        
        // Recursively process the field value
        try obj.put(field.name, try zmplValue(field_value, alloc));
    }
    return Value{ .object = obj };
}
