const std = @import("std");

const compile = @import("compile.zig");

fn getGitHash(allocator: std.mem.Allocator) ![]const u8 {
    var child = std.process.Child.init(&[_][]const u8{ "git", "rev-parse", "--short=10", "HEAD" }, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    var buf = std.ArrayList(u8).init(allocator);
    const poller = std.io.poll(allocator, enum { stdout }, .{ .stdout = child.stdout.? });
    defer poller.deinit();
    while (try poller.poll()) {}
    var fifo = poller.fifo(.stdout);
    if (fifo.head != 0) fifo.realign();
    try buf.appendSlice(allocator, fifo.buf[0..fifo.count]);
    _ = try child.wait();
    return buf.toOwnedSlice(allocator);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "jetzig",
        .root_source_file = b.path("cli.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zig_args_dep = b.dependency("args", .{ .target = target, .optimize = optimize });
    const jetquery_dep = b.dependency("jetquery", .{
        .target = target,
        .optimize = optimize,
        .jetquery_migrations_path = @as([]const u8, "src/app/database/migrations"),
        .jetquery_seeders_path = @as([]const u8, "src/app/database/seeders"),
    });
    exe.root_module.addImport("jetquery", jetquery_dep.module("jetquery"));
    exe.root_module.addImport("args", zig_args_dep.module("args"));
    exe.root_module.addImport("init_data", try compile.initDataModule(b));

    // Embed version and commit hash into the CLI
    const version_config = @import("build.zig.zon");
    const version_str = version_config.version;
    var raw_hash = try getGitHash(b.allocator);
    defer b.allocator.free(raw_hash);
    const hash = std.mem.trim(u8, raw_hash, &std.ascii.whitespace);
    var content = std.ArrayList(u8).init(b.allocator);
    defer content.deinit();
    try content.appendSlice(b.allocator, "pub const version = \"");
    try content.appendSlice(b.allocator, version_str);
    try content.appendSlice(b.allocator, "\";\n");
    try content.appendSlice(b.allocator, "pub const commit_hash = \"");
    try content.appendSlice(b.allocator, hash);
    try content.appendSlice(b.allocator, "\";\n");
    const write_files = b.addWriteFiles();
    const git_info_src = write_files.add("git_info.zig", content.items);
    const git_info_module = b.createModule(.{ .root_source_file = git_info_src });
    exe.root_module.addImport("git_info", git_info_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
