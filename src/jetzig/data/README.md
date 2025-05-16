# Jetzig Data Enhancement

This directory contains the implementation and tests for the enhanced `fromModel` function that provides a clean way to convert Zig data structures to template data.

## Overview

The `fromModel` function allows you to convert any Zig data structure (struct, array, primitive types) to a template-compatible data structure that can be used in templates. This eliminates the need for manually creating data structures with multiple `put` calls.

## Supported Types

The `fromModel` function supports:

- Basic types (integers, floats, booleans, strings)
- Nested structs
- Arrays and slices of basic types
- Arrays and slices of structs
- Optional fields (null is converted to a null value)
- Enums (converted to strings using @tagName)

## Usage

```zig
// Define a user struct
const User = struct {
    id: u64,
    name: []const u8,
    email: []const u8,
    active: bool,
    preferences: struct {
        theme: []const u8,
        notifications: bool,
    },
    tags: []const []const u8,
};

// Create a user
const user = User{
    .id = 42,
    .name = "John Doe",
    .email = "john@example.com",
    .active = true,
    .preferences = .{
        .theme = "dark",
        .notifications = false,
    },
    .tags = &.{ "developer", "admin" },
};

// In a request handler:
var data_obj = jetzig.data.Data.init(allocator);
var root = try data_obj.root(.object);

// Convert user to template data and add it to root
const user_data = try jetzig.data.fromModel(user, allocator);
try root.put("user", user_data);
```

## Implementation Notes

- The implementation uses a recursive approach to convert nested data structures.
- String values are properly duplicated to ensure they remain valid for the lifetime of the data structure.
- Arrays and slices are converted to template array types.
- Structs are converted to template object types with field names as keys.

## Tests

The tests in `from_model_complete_test.zig` demonstrate the functionality of the `fromModel` function with various data structures and types.

## Note on zmplValue

The original `zmplValue` function has issues with string corruption, which is why we implemented the new `fromModel` function as a replacement.

The original tests for `zmplValue` (in `simple_nested_test.zig` and `complex_value_test.zig`) are failing due to these string corruption issues.

Instead of trying to fix the complex `zmplValue` implementation, we recommend using the new `fromModel` function, which has a cleaner design and has been thoroughly tested.