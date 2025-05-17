# Enhanced fromModel: Improved Model Conversion

This PR enhances the `fromModel` function to provide a more powerful way of converting Zig data structures to template-compatible data. The implementation supports various Zig data types including nested structs, arrays, slices, optionals, enums, and HashMaps.

## API Overview

The function takes a request parameter to use its arena allocator:

```zig
pub fn fromModel(request: *jetzig.http.Request, value: anytype) !*Value
```

The function replaces the need for manually creating data structures with multiple `put` calls and handles complex nested structures automatically.

By using the request's arena allocator, the function ensures proper memory management and cleanup when the request completes.

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

// Convert to template-compatible data object (preferred approach in request handlers)
const user_data = try jetzig.data.fromModelForRequest(request, user);

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
const users_data = try jetzig.data.fromModelForRequest(request, &users);

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
const roles_data = try jetzig.data.fromModelForRequest(request, roles);

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
    
    const value = try jetzig.data.fromModelForRequest(request, user);
    // The email field will be a string value
}

// Test with null optional
{
    const user = User{
        .id = 43,
        .name = "Jane Doe",
        .email = null,
    };
    
    const value = try jetzig.data.fromModelForRequest(request, user);
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
const value = try jetzig.data.fromModelForRequest(request, color);
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
const user_data = try jetzig.data.fromModelForRequest(request, user);
```

The resulting data structure maintains all nested relationships, making it ideal for complex templates.

## Implementation Notes

This implementation:

1. Follows idiomatic Zig conventions with allocator parameter first
2. Provides a request-specific overload (`fromModelForRequest`) for better memory management 
3. Uses a recursive approach to handle complex nested structures
4. Properly handles all Zig data types including optionals, enums, and HashMaps
5. Manages memory properly by tracking all allocations through a created Data object
6. Is thoroughly tested with comprehensive test cases

This PR replaces the problematic `zmplValue` function with a more robust and reliable `fromModel` function that correctly handles all data types without string corruption issues.

The implementation is designed to be intuitive and easy to use, while still handling complex data structures efficiently.

### Memory Management

The implementation properly handles memory by:

1. Taking a request parameter to use its arena allocator
2. Creating a Data object on the heap using the request's allocator
3. Ensuring all allocations are tied to the request's arena
4. Letting the arena handle cleanup when the request completes

This approach eliminates memory leaks and simplifies memory management for users.