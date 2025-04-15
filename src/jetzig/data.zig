const std = @import("std");

const zmpl = @import("zmpl").zmpl;

pub const Writer = zmpl.Data.Writer;
pub const Data = zmpl.Data;
pub const Value = zmpl.Data.Value;
pub const NullType = zmpl.Data.NullType;
pub const Float = zmpl.Data.Float;
pub const Integer = zmpl.Data.Integer;
pub const Boolean = zmpl.Data.Boolean;
pub const String = zmpl.Data.String;
pub const Object = zmpl.Data.Object;
pub const Array = zmpl.Data.Array;
pub const ValueType = zmpl.Data.ValueType;

// Import the Value formatter to make Value work with std.debug.print("{any}")
pub usingnamespace @import("data/ValueFormat.zig");
