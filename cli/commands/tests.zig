const std = @import("std");
const util = @import("../util.zig");

/// Command line options for the `generate` command.
pub const Options = struct {
    @"fail-fast": bool = false,

    pub const shorthands = .{
        .f = "fail-fast",
    };

    pub const meta = .{
        .usage_summary = "[--fail-fast]",
        .full_text =
        \\Run app tests.
        \\
        \\Execute all tests found in `src/main.zig`
        \\
        ,
        .option_docs = .{
            .path = "Set the output path relative to the current directory (default: current directory)",
        },
    };
};

/// Run the job generator. Create a job in `src/app/jobs/`
pub fn run(
    allocator: std.mem.Allocator,
    options: Options,
    writer: anytype,
    positionals: [][]const u8,
    other_options: struct { help: bool },
) !void {
    _ = options;
    _ = writer;
    _ = positionals;
    _ = other_options;
    try util.execCommand(allocator, &.{
        "zig",
        "build",
        "jetzig:test",
    });
}
