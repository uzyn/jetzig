# Enhanced fromModel: Improved Model Conversion

This PR enhances the `fromModel` function to provide a more powerful way of converting Zig data structures to template-compatible data. The implementation supports various Zig data types including nested structs, arrays, slices, optionals, enums, and HashMaps.

## API Overview

The function follows idiomatic Zig conventions with the allocator parameter first:

```zig
pub fn fromModel(allocator: std.mem.Allocator, value: anytype) !*Value
```

The function replaces the need for manually creating data structures with multiple `put` calls and handles complex nested structures automatically.

## Basic Usage

### Converting a Single Model

```zig
const User = struct {
    id: u64,
    name: []const u8,
    email: []const u8,
    active: bool,
};

const user = User{
    .id = 42,
    .name = "John Doe",
    .email = "john@example.com",
    .active = true,
};

// Convert to template-compatible data object
const user_data = try jetzig.data.fromModel(allocator, user);

// Use in your template context
try response.render(.{
    .template = "users/show.zmpl",
    .context = .{
        .user = user_data,
    },
});
```

### Converting an Array of Models

```zig
var users = [_]User{
    .{ .id = 1, .name = "John Doe", .email = "john@example.com", .active = true },
    .{ .id = 2, .name = "Jane Doe", .email = "jane@example.com", .active = false },
};

// Convert array to template-compatible data array
const users_data = try jetzig.data.fromModel(allocator, &users);

// Use in your template context
try response.render(.{
    .template = "users/index.zmpl",
    .context = .{
        .users = users_data,
    },
});
```

### Converting a HashMap

```zig
// Create a string map
var roles = std.StringHashMap(bool).init(allocator);
defer roles.deinit();

try roles.put("admin", true);
try roles.put("editor", false);

// Convert to template data
const roles_data = try jetzig.data.fromModel(allocator, roles);

// Use in template context
try response.render(.{
    .template = "users/roles.zmpl",
    .context = .{
        .roles = roles_data,
    },
});
```

## Supported Types

The `fromModel` function supports a wide range of Zig types:

- Basic types (integers, floats, booleans, strings)
- Structs and nested structs 
- Arrays and slices of basic types
- Arrays and slices of structs
- Optional fields (null is converted to a null value)
- Enums (converted to strings using @tagName)
- HashMaps (converted to objects)

### Handling Optional Fields

The function properly handles optional fields by converting them to null values in templates:

```zig
const User = struct {
    id: u64,
    name: []const u8,
    email: ?[]const u8, // Optional email field
};

// Test with present optional
{
    const user = User{
        .id = 42,
        .name = "John Doe",
        .email = "john@example.com",
    };
    
    const value = try jetzig.data.fromModel(allocator, user);
    // The email field will be a string value
}

// Test with null optional
{
    const user = User{
        .id = 43,
        .name = "Jane Doe",
        .email = null,
    };
    
    const value = try jetzig.data.fromModel(allocator, user);
    // The email field will be a null value
}
```

### Handling Enums

Enums are converted to their string representations:

```zig
const Color = enum {
    red,
    green,
    blue,
};

const color = Color.green;
const value = try jetzig.data.fromModel(allocator, color);
// value will be the string "green"
```

## Handling Complex Nested Structures

The `fromModel` function automatically handles deeply nested structures, including:

- Objects within objects
- Arrays of primitives
- Arrays of objects
- Arrays of arrays
- Any combination of the above

```zig
const Address = struct {
    street: []const u8,
    city: []const u8,
};

const Comment = struct {
    id: u32,
    text: []const u8,
};

const Post = struct {
    id: u64,
    title: []const u8,
    comments: []const Comment,
};

const User = struct {
    id: u64,
    name: []const u8,
    address: Address,
    posts: []const Post,
    tags: []const []const u8,
};

// Create comments
const comments1 = [_]Comment{
    .{ .id = 1, .text = "Great post!" },
    .{ .id = 2, .text = "Thanks" },
};

const comments2 = [_]Comment{
    .{ .id = 3, .text = "Interesting" },
};

// Create posts
const posts = [_]Post{
    .{ .id = 101, .title = "First Post", .comments = &comments1 },
    .{ .id = 102, .title = "Second Post", .comments = &comments2 },
};

// Create tags
const tags = [_][]const u8{ "developer", "zig", "web" };

// Create user with nested structures
const user = User{
    .id = 42,
    .name = "John Doe",
    .address = .{
        .street = "123 Main St",
        .city = "Anytown",
    },
    .posts = &posts,
    .tags = &tags,
};

// Convert to template data with a single call
const user_data = try jetzig.data.fromModel(allocator, user);
```

The resulting data structure maintains all nested relationships, making it ideal for complex templates.

## Implementation Notes

This implementation:

1. Follows idiomatic Zig conventions with allocator parameter first
2. Uses a recursive approach to handle complex nested structures
3. Properly handles all Zig data types including optionals, enums, and HashMaps
4. Is thoroughly tested with comprehensive test cases

This PR replaces the problematic `zmplValue` function with a more robust and reliable `fromModel` function that correctly handles all data types without string corruption issues.

The implementation is designed to be intuitive and easy to use, while still handling complex data structures efficiently.