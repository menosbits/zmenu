const std = @import("std");
const OpenError = std.Io.Dir.OpenError;

const location = struct {
    path: []const u8,
    home_dir: bool,

    fn at_home(self: @This()) bool {
        return self.home_dir;
    }
};

const locations = [6]location{
    .{ .path = "/usr/share/applications", .home_dir = false },
    .{ .path = "/usr/local/share/applications", .home_dir = false },
    .{ .path = "/var/lib/snapd/desktop/applications", .home_dir = false },
    .{ .path = "/var/lib/flatpak/exports/share/applications", .home_dir = false },
    .{ .path = "/.local/share/applications", .home_dir = true },
    .{ .path = "/.local/share/applications/wine/Programs", .home_dir = true },
};

const app = struct {
    path: []const u8,
    description: []const u8,
    command: []const u8,
    terminal: bool,

    fn new(path: []const u8) app {
        return &app{ .path = path };
    }
};

// list every file in path and returns a slice of apps structs
fn list_app_files(allocator: std.mem.Allocator, io: std.Io, path: []const u8) OpenError![]app {
    var app_list: std.ArrayList(app) = undefined;
    var dir = try std.Io.Dir.cwd().openDir(
        io,
        path,
        .{ .iterate = true },
    );
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |file| {
        const ext = std.Io.Dir.path.extension(file.name);
        if (std.mem.eql(u8, ext, ".desktop")) {
            try app_list.append(allocator, app.new(path));
        }
    }

    return app_list.toOwnedSlice(allocator);
}

// list every app in system and parse their files
pub fn find(allocator: std.mem.Allocator, io: std.Io, env_vars: *std.process.Environ.Map) !std.ArrayList(app) {
    var app_list: std.ArrayList(app) = undefined;
    defer app_list.deinit(allocator);

    // list app files
    for (locations) |loc| {
        if (loc.at_home()) {
            const home_dir = env_vars.get("HOME");
            var path: []const u8 = undefined;
            path = try std.Io.Dir.path.join(allocator, &[_][]const u8{ home_dir.?, loc.path });
            loc.path = path;
        }
        try app_list.appendSlice(allocator, list_app_files(allocator, io, loc));
    }
    // parse app file

    return app_list.toOwnedSlice(allocator);
}
