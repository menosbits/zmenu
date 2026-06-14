const std = @import("std");
const apps = @import("apps.zig");
const testing = std.testing;
const Config = @import("config.zig").Config;

pub fn log(allocator: std.mem.Allocator, io: std.Io, app: apps.Application, full_cmd: [][]const u8, config: *Config) !void {
    const path = "/tmp/.zmenu_log";

    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);

    var buffer: [2048]u8 = undefined;
    var file_writer = file.writer(io, &buffer);
    const writer_interface = &file_writer.interface;

    const fc = try std.mem.join(allocator, " ", full_cmd);
    defer allocator.free(fc);

    try writer_interface.print("[Application]\npath: {s}\ncmd: {s}\nfull_cmd: {s}\nterm: {}\n", .{
        app.path,
        app.command,
        fc,
        app.terminal,
    });

    if (config.terminal) |t| {
        try writer_interface.print("\n[Config]\nterm: {s}\n", .{t});
    } else if (app.terminal) {
        try writer_interface.print("\n[Config]\nterm: ERROR! TERMINAL NOT FOUND!\n", .{});
    }
    try writer_interface.flush();
}

//TODO: print error if terminal is not found
pub fn get_terminal(allocator: std.mem.Allocator, io: std.Io, terminal: ?[]const u8) ![][]const u8 {
    if (terminal) |t| {
        var full_path: []const u8 = undefined;
        defer allocator.free(full_path);

        if (std.mem.startsWith(u8, t, "/")) {
            full_path = try allocator.dupe(u8, t);
        } else {
            full_path = try std.fmt.allocPrint(allocator, "/bin/{s}", .{t});
        }

        std.Io.Dir.cwd().access(io, full_path, .{ .execute = true }) catch return error.TerminalNotFound;

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

test "get_terminal relative path" {
    const allocator = testing.allocator;

    const config = Config{ .terminal = "ghostty" };

    const expected = try allocator.dupe([]const u8, &[_][]const u8{ "ghostty", "-e" });
    defer allocator.free(expected);

    const got = try get_terminal(allocator, testing.io, config.terminal);
    defer allocator.free(got);

    try testing.expectEqualStrings(expected[0], got[0]);
    try testing.expectEqualStrings(expected[1], got[1]);
}

test "get_terminal full path" {
    const allocator = testing.allocator;

    const config = Config{ .terminal = "/bin/ghostty" };

    const expected = try allocator.dupe([]const u8, &[_][]const u8{ "/bin/ghostty", "-e" });
    defer allocator.free(expected);

    const got = try get_terminal(allocator, testing.io, config.terminal);
    defer allocator.free(got);

    try testing.expectEqualStrings(expected[0], got[0]);
    try testing.expectEqualStrings(expected[1], got[1]);
}

test "get_terminal not found" {
    const allocator = testing.allocator;
    const config = Config{ .terminal = "foot" };
    const got = get_terminal(allocator, testing.io, config.terminal);
    try testing.expectError(error.TerminalNotFound, got);
}
