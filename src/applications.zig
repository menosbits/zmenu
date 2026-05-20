//! This module provides functions to locate and extract information from
//! application's desktop files in Linux system.

const std = @import("std");
const testing = std.testing;

/// Location: a struct that represents a candidate directory to search for
/// .desktop files.
///
/// Fields:
/// - path: path string.
/// - home_dir: true if path should be joined to $HOME.
const Location = struct {
    path: []const u8,
    home_dir: bool,

    /// Small convenience helper used by callers to detect HOME-based locations.
    fn at_home(self: Location) bool {
        return self.home_dir;
    }
};

/// Default application's locations to probe.
var locations = [6]Location{
    .{ .path = "/usr/share/applications/", .home_dir = false },
    .{ .path = "/usr/local/share/applications/", .home_dir = false },
    .{ .path = "/var/lib/snapd/desktop/applications/", .home_dir = false },
    .{ .path = "/var/lib/flatpak/exports/share/applications/", .home_dir = false },
    .{ .path = "/.local/share/applications/", .home_dir = true },
    .{ .path = "/.local/share/applications/wine/Programs/", .home_dir = true },
};

/// Application: a struct that represents a discovered .desktop file.
///
/// Fields:
/// - path: a slice representing the application's path.
/// - name: the application's name.
/// - description: the application's description.
/// - command: the command to run the application.
/// - terminal: whether or not the application should be runned in terminal.
const Application = struct {
    path: []const u8,
    name: []const u8 = "",
    description: []const u8 = "",
    command: []const u8 = "",
    terminal: bool = false,
    display: bool = true,

    /// Construct an Application with the given path slice.
    fn create(path: []const u8) Application {
        return Application{ .path = path };
    }

    /// Free any owned memory inside the Application using allocator.
    /// After calling destroy, the Application value must not be used again.
    pub fn destroy(self: Application, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.free(self.command);
    }

    /// Read app's .desktop file and parse the following information:
    ///
    /// - name: the application's name.
    /// - description: the application's description.
    /// - command: the command to run the application.
    /// - terminal: whether or not the application should be runned in terminal.
    ///
    /// TODO: consider the system's locale.
    fn parse_data(self: *Application, allocator: std.mem.Allocator, io: std.Io) !void {
        const f_content = try std.Io.Dir.cwd().openFile(io, self.path, .{ .mode = .read_only });
        defer f_content.close(io);

        const f_buffer_len = try f_content.length(io);
        const f_buffer = try allocator.alloc(u8, f_buffer_len);
        defer allocator.free(f_buffer);

        var f_reader = f_content.reader(io, f_buffer);
        var reader = &f_reader.interface;

        while (try reader.takeDelimiter('\n')) |line| {
            var info_token = std.mem.tokenizeScalar(u8, line, '=');
            const info_name = info_token.next();

            if (info_name) |in| {
                if (std.mem.eql(u8, in, "NoDisplay")) {
                    const tok = info_token.next();
                    if (tok) |value| {
                        if (std.mem.eql(u8, value, "false")) self.display = false;
                    }
                }
                if (std.mem.eql(u8, in, "Name")) {
                    const tok = info_token.next();
                    if (tok) |value| {
                        self.name = try std.mem.Allocator.dupe(allocator, u8, value);
                    }
                }
                if (std.mem.eql(u8, in, "Exec")) {
                    const tok = info_token.next();
                    if (tok) |value| {
                        self.command = try std.mem.Allocator.dupe(allocator, u8, value);
                    }
                }
                if (std.mem.eql(u8, in, "Comment")) {
                    const tok = info_token.next();
                    if (tok) |value| {
                        self.description = try std.mem.Allocator.dupe(allocator, u8, value);
                    }
                }
                if (std.mem.eql(u8, in, "Terminal")) {
                    const tok = info_token.next();
                    if (tok) |value| {
                        if (std.mem.eql(u8, value, "true")) self.terminal = true;
                    }
                }
            }
        }
    }

    test "parse_data read .desktop test file" {
        const allocator = testing.allocator;
        const expected = Application{
            .path = try allocator.dupe(u8, "/tmp/znur_test/file.desktop"),
            .name = try allocator.dupe(u8, "file tester"),
            .description = try allocator.dupe(u8, "A test .desktop file"),
            .command = try allocator.dupe(u8, "echo 'a test desktop file'"),
            .terminal = true,
        };
        defer expected.destroy(allocator);

        const test_location: Location = .{ .path = "/tmp/znur_test/", .home_dir = false };

        const test_location_dir = try std.Io.Dir.cwd().createDirPathOpen(testing.io, test_location.path, .{
            .open_options = .{ .iterate = true },
            .permissions = .default_dir,
        });
        defer {
            test_location_dir.close(testing.io);
            std.Io.Dir.cwd().deleteDir(testing.io, test_location.path) catch unreachable;
        }

        const test_file = try std.Io.Dir.cwd().createFile(testing.io, expected.path, .{ .exclusive = true });
        defer {
            test_file.close(testing.io);
            std.Io.Dir.cwd().deleteFile(testing.io, expected.path) catch unreachable;
        }

        const test_file_content =
            \\Name=file tester
            \\Comment=A test .desktop file
            \\Type=Application
            \\StartupNotify=false
            \\Exec=echo 'a test desktop file'
            \\Terminal=true
        ;

        try test_file.writeStreamingAll(testing.io, test_file_content);

        var got = Application{ .path = try allocator.dupe(u8, "/tmp/znur_test/file.desktop") };
        defer got.destroy(allocator);

        try got.parse_data(allocator, testing.io);

        try testing.expectEqualDeep(expected, got);
    }
};

/// Enumerate location.path and return an owned slice of Application entries
/// for every file whose extension is ".desktop".
///
/// On success returns a slice allocated with allocator. The caller must free
/// it.
///
/// Each Application.path is an owned allocation produced with std.mem.concat
/// using allocator. Application.destroy frees it.
///
/// If the directory does not exist or cannot be opened, the function returns
/// an empty owned slice — callers must always free it.
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
        std.Io.Dir.cwd().deleteDir(testing.io, test_location.path) catch unreachable;
    }

    const test_file = try std.Io.Dir.cwd().createFile(testing.io, expected, .{ .exclusive = true });
    defer {
        test_file.close(testing.io);
        std.Io.Dir.cwd().deleteFile(testing.io, expected) catch unreachable;
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
        std.Io.Dir.cwd().deleteDir(testing.io, test_location.path) catch unreachable;
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
        std.Io.Dir.cwd().deleteDir(testing.io, test_location.path) catch unreachable;
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
        std.Io.Dir.cwd().deleteFile(testing.io, test_file_two_path) catch unreachable;
    }

    const files = list_app_files(allocator, testing.io, test_location);
    try testing.expectError(error.OutOfMemory, files);
}

/// Iterate over the global locations array, resolving HOME-based entries
/// by joining with the HOME environment variable (obtained from env_vars),
/// call list_app_files for each location, and append results into an
/// aggregated owned slice returned to the caller.
///
/// Caller responsibilities:
/// - free each Application.path via Application.destroy(allocator)
/// - free the returned slice with allocator.free(slice)
pub fn find(allocator: std.mem.Allocator, io: std.Io, env_vars: *std.process.Environ.Map) ![]Application {
    var app_list = try std.ArrayList(Application).initCapacity(allocator, 1);
    errdefer app_list.deinit(allocator);

    // Get application's files locations
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

    // Parse application's files
    for (app_list.items) |*app| {
        try app.parse_data(allocator, io);
    }

    return app_list.toOwnedSlice(allocator);
}

/// Iterate over a list of applications and extract its names, returning a
/// slice with all applications' names
pub fn get_apps_names(allocator: std.mem.Allocator, app_list: []Application) ![][]const u8 {
    var apps_names_list = try std.ArrayList([]const u8).initCapacity(allocator, app_list.len);
    errdefer apps_names_list.deinit(allocator);

    for (app_list) |app| {
        try apps_names_list.append(allocator, app.name);
    }

    const apps_names = try apps_names_list.toOwnedSlice(allocator);

    std.mem.sort([]const u8, apps_names, {}, struct {
        fn compare(_: void, a: []const u8, b: []const u8) bool {
            var bufa: [96]u8 = undefined;
            var bufb: [96]u8 = undefined;

            const al = std.ascii.lowerString(&bufa, a);
            const bl = std.ascii.lowerString(&bufb, b);

            return std.mem.order(u8, al, bl) == .lt;
        }
    }.compare);

    return apps_names;
}

test "get_apps_names extract names" {
    const allocator = testing.allocator;

    const app_list = try allocator.dupe(Application, &[_]Application{
        .{ .path = "/test/app1/", .name = "App1" },
        .{ .path = "/test/app2/", .name = "App2" },
        .{ .path = "/test/app3/", .name = "App3" },
    });
    defer allocator.free(app_list);

    const expected = [_][]const u8{ "App1", "App2", "App3" };
    const got = try get_apps_names(allocator, app_list);
    defer allocator.free(got);

    try testing.expectEqualSlices([]const u8, &expected, got);
}

test "get_apps_names failing leaks" {
    const ta = testing.allocator;
    var fa = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
    const allocator = fa.allocator();

    const app_list = try ta.dupe(Application, &[_]Application{
        .{ .path = "/test/app1/", .name = "App1" },
        .{ .path = "/test/app2/", .name = "App2" },
        .{ .path = "/test/app3/", .name = "App3" },
    });
    defer ta.free(app_list);

    const got = get_apps_names(allocator, app_list);
    try testing.expectError(error.OutOfMemory, got);
}

test "get_apps_names is sorted" {
    const allocator = testing.allocator;
    const app_list = try allocator.dupe(Application, &[_]Application{
        .{ .path = "/test/app1/", .name = "App1" },
        .{ .path = "/test/app2/", .name = "App2" },
        .{ .path = "/test/app3/", .name = "App3" },
    });
    defer allocator.free(app_list);

    const got = try get_apps_names(allocator, app_list);
    defer allocator.free(got);

    const is_sorted = std.sort.isSorted([]const u8, got, {}, struct {
        fn compare(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.compare);

    try testing.expect(is_sorted);
}
