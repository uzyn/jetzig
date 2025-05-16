const std = @import("std");
const tests = @import("../../tests.zig");

pub fn main() !void {
    // Run the tests
    std.debug.print("Running direct creation test...\n", .{});
    try tests.run();
    std.debug.print("All tests passed!\n", .{});
}