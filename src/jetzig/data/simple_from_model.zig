const std = @import("std");
const jetzig = @import("../..");

/// Converts simple structs to template data
pub fn fromModel(value: anytype, allocator: std.mem.Allocator) !*jetzig.data.Value {
    const T = @TypeOf(value);
    var data = jetzig.data.Data.init(allocator);
    var root = try data.root(.object);
    
    // Handle struct conversion
    if (comptime std.meta.trait.is(.Struct)(T)) {
        comptime {
            if (!std.meta.trait.is(.Struct)(T))
                @compileError("Expected struct, got " ++ @typeName(T));
        }
        
        inline for (std.meta.fields(T)) |field| {
            const field_value = @field(value, field.name);
            
            // Handle different field types
            switch (@TypeOf(field_value)) {
                []const u8 => try root.put(field.name, data.string(field_value)),
                u8, u16, u32, u64, i8, i16, i32, i64 => try root.put(field.name, data.integer(field_value)),
                f32, f64 => try root.put(field.name, data.float(field_value)),
                bool => try root.put(field.name, data.boolean(field_value)),
                // Add more types as needed
                else => {
                    @compileLog("Unsupported field type: ", @typeName(@TypeOf(field_value)));
                    @compileError("Unsupported field type: " ++ @typeName(@TypeOf(field_value)));
                },
            }
        }
    } else {
        @compileError("Expected struct, got " ++ @typeName(T));
    }
    
    return root.value.?;
}