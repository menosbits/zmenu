const std = @import("std");

const Location = struct {
    path: []const u8,
    home_dir: bool,

    fn at_home(self: @This()) bool {
        return self.home_dir;
    }
};

var locations = [6]Location{
    .{ .path = "/usr/share/applications/", .home_dir = false },
    .{ .path = "/usr/local/share/applications/", .home_dir = false },
    .{ .path = "/var/lib/snapd/desktop/applications/", .home_dir = false },
    .{ .path = "/var/lib/flatpak/exports/share/applications/", .home_dir = false },
    .{ .path = "/.local/share/applications/", .home_dir = true },
    .{ .path = "/.local/share/applications/wine/Programs/", .home_dir = true },
};

pub const Application = struct {
    path: []const u8,
    description: []const u8 = "",
    command: []const u8 = "",
    terminal: bool = false,

    fn new(path: []const u8) Application {
        return Application{ .path = path };
    }
};

// list every file in path and returns a slice of apps structs
fn list_app_files(allocator: std.mem.Allocator, io: std.Io, location: Location) ![]Application {
    var app_list = try std.ArrayList(Application).initCapacity(allocator, 1);
    errdefer app_list.deinit(allocator);

    var dir = std.Io.Dir.cwd().openDir(
        io,
        location.path,
        .{ .iterate = true },
    ) catch return &[_]Application{};
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |file| {
        const ext = std.Io.Dir.path.extension(file.name);
        if (std.mem.eql(u8, ext, ".desktop")) {
            const new_path = try std.mem.concat(allocator, u8, &[_][]const u8{ location.path, file.name });
            try app_list.append(allocator, Application.new(new_path));
        }
    }

    return app_list.toOwnedSlice(allocator);
}

// list every app in system and parse their files
pub fn find(allocator: std.mem.Allocator, io: std.Io, env_vars: *std.process.Environ.Map) ![]Application {
    var app_list = try std.ArrayList(Application).initCapacity(allocator, 1);
    errdefer app_list.deinit(allocator);

    // list app files
    var new_location: ?Location = null;
    for (locations) |location| {
        if (location.at_home()) {
            const home_dir = env_vars.get("HOME");
            var path: []const u8 = undefined;
            path = try std.Io.Dir.path.join(allocator, &[_][]const u8{ home_dir.?, location.path });
            new_location = Location{ .path = path, .home_dir = true };
        } else {
            new_location = location;
        }
        if (new_location) |l| {
            const listed_apps = try list_app_files(allocator, io, l);
            app_list.appendSlice(allocator, listed_apps) catch continue;
        }
    }
    // parse app file

    return app_list.toOwnedSlice(allocator);
}
