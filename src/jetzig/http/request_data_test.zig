const std = @import("std");
const testing = std.testing;
const jetzig = @import("../../jetzig.zig");

// Simple model for testing
const User = struct {
    id: i64,
    name: []const u8,
};

// Test the existence of the API for coverting models
test "Request struct has fromModel method" {
    // We're only testing at compile time that the method exists
    // This validates that our implementation is correctly added to the Request struct
    
    checkRequestHasFromModelMethod(jetzig.http.Request);
}

// Compile-time check that verifies the Request struct has the required method
fn checkRequestHasFromModelMethod(comptime T: type) void {
    // Check if fromModel exists on the type
    if (!@hasDecl(T, "fromModel")) {
        @compileError("Request struct does not have a fromModel method");
    }
    
    // Check if fromModelWithOptions exists on the type
    if (!@hasDecl(T, "fromModelWithOptions")) {
        @compileError("Request struct does not have a fromModelWithOptions method");
    }
}