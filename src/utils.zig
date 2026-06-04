const std = @import("std");
const apps = @import("apps.zig");
const testing = std.testing;

pub fn log(allocator: std.mem.Allocator, io: std.Io, app: apps.Application, full_cmd: [][]const u8) !void {
    const path = "/tmp/.zmenu_log";

    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);

    var buffer: [2048]u8 = undefined;
    var file_writer = file.writer(io, &buffer);
    const writer_interface = &file_writer.interface;

    const fc = try std.mem.join(allocator, " ", full_cmd);
    defer allocator.free(fc);

    try writer_interface.print("path: {s}\ncmd: {s}\nfull_cmd: {s}\nterm: {}\n", .{
        app.path,
        app.command,
        fc,
        app.terminal,
    });
    try writer_interface.flush();
}

pub fn get_terminal(allocator: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map) ![][]const u8 {
    const term = env.get("TERM");
    if (term) |t| {
        const term_cmd = try allocator.dupe([]const u8, &[_][]const u8{ t, "-e" });
        return term_cmd;
    } else {
        const terminals = [_][]const u8{
            "x-terminal-emulator",
            "ghostty",
            "foot",
            "wezterm",
            "kitty",
            "alacritty",
            "konsole",
            "mate-terminal",
            "xfce-terminal.wrapper",
            "gnome-terminal",
            "xterm",
            "aterm",
            "lxterminal",
            "uxterm",
            "roxterm",
            "Eterm",
            "qterminal",
            "st",
            "urxvt",
            "rxvt",
            "terminology",
        };

        for (terminals) |t| {
            const full_path = try std.fmt.allocPrint(allocator, "/bin/{s}", .{t});

            std.Io.Dir.cwd().access(io, full_path, .{ .execute = true }) catch continue;
            const term_cmd = try allocator.dupe([]const u8, &[_][]const u8{ full_path, "-e" });

            return term_cmd;
        }
    }

    return error.TerminalNotFound;
}

test "get_terminal" {
    const allocator = testing.allocator;

    var environ_map = try testing.environ.createMap(allocator);
    try environ_map.put("TERM", "ghostty");
    defer environ_map.deinit();

    const expected = try allocator.dupe([]const u8, &[_][]const u8{ "ghostty", "-e" });
    defer allocator.free(expected);

    const got = try get_terminal(allocator, testing.io, &environ_map);
    defer allocator.free(got);

    try testing.expectEqualStrings(expected[0], got[0]);
    try testing.expectEqualStrings(expected[1], got[1]);
}
