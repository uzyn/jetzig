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

// Model to Data conversion utilities
pub const model_to_data = @import("data/model_to_data.zig");
pub const ModelToDataOptions = model_to_data.ModelToDataOptions;
pub const TransformerFn = model_to_data.TransformerFn;
pub const TransformerMap = model_to_data.TransformerMap;
pub const modelToData = model_to_data.modelToData;
pub const modelToDataWithOptions = model_to_data.modelToDataWithOptions;
pub const modelsToArray = model_to_data.modelsToArray;
