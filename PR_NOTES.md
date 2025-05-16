# PR for Enhanced fromModel Function

This PR adds a new `fromModel` function to the Jetzig framework that makes it easy to convert Zig structs and other data types to template-compatible data structures. 

## Problem

Previously, to use complex Zig data structures in templates, developers had to manually convert each field using multiple `put` calls. For nested structures, this became very verbose and error-prone.

While PR #1 attempted to address this with a separate `fromModel` function, we've taken a different approach by implementing a more powerful version directly in the `jetzig.data` module.

## Solution

The new `fromModel` function allows developers to convert any Zig data structure to a template-compatible Value with a single function call. This includes:

- Basic types (integers, floats, booleans, strings)
- Nested structs
- Arrays and slices of basic types
- Arrays and slices of structs
- Optional fields
- Enums

## Usage Example

```zig
// Define a complex struct
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

// Convert user to template data with one call
const user_data = try jetzig.data.fromModel(user, allocator);
try root.put("user", user_data);
```

Compare with the old approach:

```zig
// Manual creation (verbose and error-prone)
try root.put("id", data_obj.integer(user.id));
try root.put("name", data_obj.string(user.name));
try root.put("email", data_obj.string(user.email));
try root.put("active", data_obj.boolean(user.active));

// Nested objects require even more code
var preferences = try jetzig.data.Data.createObject(allocator);
try preferences.put("theme", data_obj.string(user.preferences.theme));
try preferences.put("notifications", data_obj.boolean(user.preferences.notifications));
try root.put("preferences", preferences);

// Arrays require creating array objects and looping
var tags = try jetzig.data.Data.createArray(allocator);
for (user.tags) |tag| {
    try tags.append(data_obj.string(tag));
}
try root.put("tags", tags);
```

## Implementation Details

The implementation uses a recursive approach to handle nested data structures. It detects the type of the input value at compile-time and converts it to the appropriate template Value type.

Key features:
- Proper memory management with arena allocators
- Comprehensive test coverage with various data structures
- Handles all common Zig data types

## Notes

- We explored enhancing the `zmplValue` function but encountered string corruption issues
- Instead, we implemented the `fromModel` function which uses the direct data creation approach (proven to work correctly)
- All tests for the new implementation pass successfully

## Future Work

For even more ergonomic usage, a future PR could add a convenience method to the Request object:

```zig
// Current usage
const user_data = try jetzig.data.fromModel(user, allocator);
try root.put("user", user_data);

// Potential future API
try request.fromModel("user", user);
```

This would further reduce boilerplate and make the API more intuitive.