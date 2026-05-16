const std = @import("std");
const testing = std.testing;

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

    fn create(path: []const u8) Application {
        return Application{ .path = path };
    }

    fn destroy(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

// list every file in path and returns a slice of apps structs
fn list_app_files(allocator: std.mem.Allocator, io: std.Io, location: Location) ![]Application {
    var app_list = try std.ArrayList(Application).initCapacity(allocator, 1);
    errdefer {
        for (app_list.items) |app| app.destroy(allocator);
        app_list.deinit(allocator);
    }

    var dir = std.Io.Dir.cwd().openDir(
        io,
        location.path,
        .{ .iterate = true },
    ) catch return app_list.toOwnedSlice(allocator);
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |file| {
        const ext = std.Io.Dir.path.extension(file.name);
        if (std.mem.eql(u8, ext, ".desktop")) {
            const new_path = try std.mem.concat(allocator, u8, &[_][]const u8{ location.path, file.name });
            try app_list.append(allocator, Application.create(new_path));
        }
    }

    return app_list.toOwnedSlice(allocator);
}

test "list_app_files temp dir" {
    const allocator = testing.allocator;
    const expected: []const u8 = "/tmp/znur_test/list_app_files.desktop";

    const test_location: Location = .{ .path = "/tmp/znur_test/", .home_dir = false };

    const test_location_dir = try std.Io.Dir.cwd().createDirPathOpen(testing.io, test_location.path, .{
        .open_options = .{ .iterate = true },
        .permissions = .default_dir,
    });
    defer {
        test_location_dir.close(testing.io);
        std.Io.Dir.cwd().deleteDir(testing.io, test_location.path) catch {};
    }

    const test_file = try std.Io.Dir.cwd().createFile(testing.io, expected, .{ .exclusive = true });
    defer {
        test_file.close(testing.io);
        std.Io.Dir.cwd().deleteFile(testing.io, expected) catch {};
    }

    const files: []Application = try list_app_files(allocator, testing.io, test_location);
    defer {
        for (files) |f| f.destroy(allocator);
        allocator.free(files);
    }

    try testing.expect(files.len == 1);

    const got = files[0].path;
    try testing.expectEqualStrings(got, expected);
}

test "list_app_files nonexistent directory" {
    const allocator = testing.allocator;
    const test_location: Location = .{ .path = "/nonexistent/", .home_dir = false };

    const files: []Application = try list_app_files(allocator, testing.io, test_location);
    defer allocator.free(files);

    try testing.expect(files.len == 0);
}

test "list_app_files empty directory" {
    const allocator = testing.allocator;
    const test_location: Location = .{ .path = "/tmp/znur_test/", .home_dir = false };

    const test_location_dir = try std.Io.Dir.cwd().createDirPathOpen(testing.io, test_location.path, .{
        .open_options = .{ .iterate = true },
        .permissions = .default_dir,
    });
    defer {
        test_location_dir.close(testing.io);
        std.Io.Dir.cwd().deleteDir(testing.io, test_location.path) catch {};
    }

    const files: []Application = try list_app_files(allocator, testing.io, test_location);
    defer allocator.free(files);

    try testing.expect(files.len == 0);
}

test "list_app_files failing leaks" {
    var fa = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1, .resize_fail_index = 1 });
    const allocator = fa.allocator();
    const test_location: Location = .{ .path = "/tmp/znur_test/", .home_dir = false };

    const test_location_dir = try std.Io.Dir.cwd().createDirPathOpen(testing.io, test_location.path, .{
        .open_options = .{ .iterate = true },
        .permissions = .default_dir,
    });
    defer {
        test_location_dir.close(testing.io);
        std.Io.Dir.cwd().deleteDir(testing.io, test_location.path) catch {};
    }

    const test_file_one_path = test_location.path ++ "test_file_one.desktop";
    const test_file_one = try std.Io.Dir.cwd().createFile(testing.io, test_file_one_path, .{ .exclusive = true });
    defer {
        test_file_one.close(testing.io);
        std.Io.Dir.cwd().deleteFile(testing.io, test_file_one_path) catch {};
    }

    const test_file_two_path = test_location.path ++ "test_file_two.desktop";
    const test_file_two = try std.Io.Dir.cwd().createFile(testing.io, test_file_two_path, .{ .exclusive = true });
    defer {
        test_file_two.close(testing.io);
        std.Io.Dir.cwd().deleteFile(testing.io, test_file_two_path) catch {};
    }

    const files = list_app_files(allocator, testing.io, test_location);
    try testing.expectError(error.OutOfMemory, files);
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
        const listed_apps = try list_app_files(allocator, io, new_location.?);
        app_list.appendSlice(allocator, listed_apps) catch continue;
    }
    // parse app file

    return app_list.toOwnedSlice(allocator);
}
