const std = @import("std");
const args = @import("args");
const git_info = @import("git_info");

/// Command line options for the `version` command.
pub const Options = struct {
    pub const meta = .{
        .usage_summary = "",
        .full_text = "Prints Jetzig version.",
    };
};

/// Run the `jetzig version` command.
pub fn run(
    allocator: std.mem.Allocator,
    options: Options,
    writer: anytype,
    T: type,
    main_options: T,
) !void {
    if (main_options.options.help) {
        try args.printHelp(Options, "jetzig version", writer);
        return;
    }
    std.debug.print("{s}+{s}\n", .{ git_info.version, git_info.commit_hash });
}
