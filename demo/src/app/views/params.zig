const std = @import("std");
const jetzig = @import("jetzig");

pub fn index(request: *jetzig.Request) !jetzig.View {
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {
    // Demonstrating the parameters debug dump
    const params_value = try request.params();
    
    // Format and print parameters - makes debugging easier
    const formatted_params = try request.formatParameters(params_value);
    std.debug.print("{s}\n", .{formatted_params});
    
    // Alternative direct debug output:
    std.debug.print("{any}\n", .{params_value});
    
    const Params = struct {
        // Required param - `expectParams` returns `null` if not present:
        name: []const u8,
        // Enum params are converted from string, `expectParams` returns `null` if no match:
        favorite_animal: enum { cat, dog, raccoon },
        // Optional params are not required. Numbers are coerced from strings. `expectParams`
        // returns `null` if a type coercion fails.
        age: ?u8 = 100,
    };
    const params = try request.expectParams(Params) orelse {
        // Inspect information about the failed params with `request.paramsInfo()`:
        // std.debug.print("{?}\n", .{try request.paramsInfo()});
        return request.fail(.unprocessable_entity);
    };

    var root = try request.data(.object);
    try root.put("info", params);

    return request.render(.created);
}

test "post query params" {
    var app = try jetzig.testing.app(std.testing.allocator, @import("routes"));
    defer app.deinit();

    const response1 = try app.request(.POST, "/params", .{
        .params = .{
            .name = "Bob",
            .favorite_animal = "raccoon",
        },
    });
    try response1.expectStatus(.created);

    const response2 = try app.request(.POST, "/params", .{
        .params = .{
            .name = "Bob",
            .favorite_animal = "platypus",
        },
    });
    try response2.expectStatus(.unprocessable_entity);

    const response3 = try app.request(.POST, "/params", .{
        .params = .{
            .name = "", // empty param
            .favorite_animal = "raccoon",
        },
    });
    try response3.expectStatus(.unprocessable_entity);
}

test "post json" {
    var app = try jetzig.testing.app(std.testing.allocator, @import("routes"));
    defer app.deinit();

    const response1 = try app.request(.POST, "/params", .{
        .json = .{
            .name = "Bob",
            .favorite_animal = "raccoon",
        },
    });
    try response1.expectJson("$.info.name", "Bob");
    try response1.expectJson("$.info.favorite_animal", "raccoon");
    try response1.expectJson("$.info.age", 100);

    const response2 = try app.request(.POST, "/params", .{
        .json = .{
            .name = "Hercules",
            .favorite_animal = "cat",
            .age = 11,
        },
    });
    try response2.expectJson("$.info.name", "Hercules");
    try response2.expectJson("$.info.favorite_animal", "cat");
    try response2.expectJson("$.info.age", 11);

    const response3 = try app.request(.POST, "/params", .{
        .json = .{
            .name = "Hercules",
            .favorite_animal = "platypus",
            .age = 11,
        },
    });
    try response3.expectStatus(.unprocessable_entity);
}

// Test for formatParameters function
test "format parameters" {
    var app = try jetzig.testing.app(std.testing.allocator, @import("routes"));
    defer app.deinit();
    
    // Create a request object
    var request = try app.createRequest(.POST, "/params", .{
        .json = .{
            .name = "TestUser",
            .age = 42,
            .nested = .{
                .value = "nested value",
            },
            .array = .{
                "item1",
                "item2",
            },
        },
    });
    defer app.deinitRequest(&request);
    
    // Get parameters
    const params_value = try request.params();
    
    // Format parameters
    const formatted = try request.formatParameters(params_value);
    
    // Verify the formatted string contains expected elements
    try std.testing.expect(std.mem.indexOf(u8, formatted, "TestUser") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "42") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "nested value") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "item1") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "item2") != null);
}

// Test formatParameters for different parameter types
test "format different parameter types" {
    var app = try jetzig.testing.app(std.testing.allocator, @import("routes"));
    defer app.deinit();
    
    // Create data for parameter testing
    var data = jetzig.data.Data.init(std.testing.allocator);
    defer data.deinit();
    
    var root = try data.root(.object);
    
    // Add different types
    try root.put("string_value", data.string("test string"));
    try root.put("int_value", data.int(123));
    try root.put("float_value", data.float(45.67));
    try root.put("bool_value", data.boolean(true));
    try root.put("null_value", data.null());
    
    // Create an array
    var array = try data.array();
    try array.append(data.string("array item"));
    try array.append(data.int(42));
    try root.put("array_value", array);
    
    // Create a nested object
    var nested = try data.object();
    try nested.put("nested_key", data.string("nested value"));
    try root.put("object_value", nested);
    
    // Create a request to access the formatter
    var request = try app.createRequest(.POST, "/params", .{});
    defer app.deinitRequest(&request);
    
    // Format and check
    const formatted = try request.formatParameters(root);
    
    // Verify all types are included in the formatted string
    try std.testing.expect(std.mem.indexOf(u8, formatted, "test string") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "45.67") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "true") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "null") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "array item") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "nested_key") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "nested value") != null);
}

// Test form post parameters
test "format form post parameters" {
    var app = try jetzig.testing.app(std.testing.allocator, @import("routes"));
    defer app.deinit();
    
    // Create a request with form data
    var request = try app.createRequest(.POST, "/params", .{
        .body = "name=FormUser&age=33&favorite_animal=raccoon&nested[param]=nested+value&array[]=value1&array[]=value2",
        .headers = &[_][2][]const u8{
            .{ "Content-Type", "application/x-www-form-urlencoded" },
        },
    });
    defer app.deinitRequest(&request);
    
    // Process the request to parse the body
    try request.process();
    
    // Get parameters
    const params_value = try request.params();
    
    // Format parameters
    const formatted = try request.formatParameters(params_value);
    
    // Verify the formatted string contains expected form values
    try std.testing.expect(std.mem.indexOf(u8, formatted, "FormUser") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "33") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "raccoon") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "nested value") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "value1") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "value2") != null);
}

// Test multipart form data parameters
test "format multipart form parameters" {
    var app = try jetzig.testing.app(std.testing.allocator, @import("routes"));
    defer app.deinit();
    
    // Create multipart form content
    const multipart_content = 
        "------WebKitFormBoundaryABC123\r\n" ++
        "Content-Disposition: form-data; name=\"name\"\r\n" ++
        "\r\n" ++
        "MultipartUser\r\n" ++
        "------WebKitFormBoundaryABC123\r\n" ++
        "Content-Disposition: form-data; name=\"age\"\r\n" ++
        "\r\n" ++
        "45\r\n" ++
        "------WebKitFormBoundaryABC123\r\n" ++
        "Content-Disposition: form-data; name=\"complex[nested][value]\"\r\n" ++
        "\r\n" ++
        "deeply nested\r\n" ++
        "------WebKitFormBoundaryABC123\r\n" ++
        "Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n" ++
        "Content-Type: text/plain\r\n" ++
        "\r\n" ++
        "Test file content\r\n" ++
        "------WebKitFormBoundaryABC123--\r\n";
    
    // Create a request with multipart form data
    var request = try app.createRequest(.POST, "/params", .{
        .body = multipart_content,
        .headers = &[_][2][]const u8{
            .{ "Content-Type", "multipart/form-data; boundary=----WebKitFormBoundaryABC123" },
        },
    });
    defer app.deinitRequest(&request);
    
    // Process the request to parse the body
    try request.process();
    
    // Get parameters
    const params_value = try request.params();
    
    // Format parameters
    const formatted = try request.formatParameters(params_value);
    
    // Verify the formatted string contains expected multipart form values
    try std.testing.expect(std.mem.indexOf(u8, formatted, "MultipartUser") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "45") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "deeply nested") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "file") != null); // File field should be present
}
