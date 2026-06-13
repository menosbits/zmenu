const apps = @import("apps.zig");
const tui = @import("tui.zig");

const std = @import("std");
const zz = @import("zigzag");
const zon = std.zon;

const Config = @import("config.zig").Config;

pub fn main(init: std.process.Init) !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    var allocator = gpa.allocator();

    var program = zz.Program(tui.Model).initWithOptions(allocator, init.io, init.environ_map, .{ .title = "zmenu" });
    defer program.deinit();

    program.model.env = init.environ_map;

    const xdg_config = init.environ_map.get("XDG_CONFIG_HOME");
    var config_path: []u8 = undefined;
    defer allocator.free(config_path);

    if (xdg_config) |xc| {
        config_path = try std.fmt.allocPrint(allocator, "{s}/zmenu/zmenu.zon", .{xc});
    } else {
        std.debug.print("[Error] Could not found $XDG_CONFIG_HOME. Include the following in your ~/.bashrc: export XDG_CONFIG_HOME=$HOME/.config\n", .{});
        return;
    }

    const config_file = try std.Io.Dir.cwd().readFileAllocOptions(init.io, config_path, allocator, .unlimited, .@"1", 0);
    defer allocator.free(config_file);

    const parsed_config = zon.parse.fromSliceAlloc(Config, allocator, config_file, null, .{ .free_on_error = true }) catch |e| {
        switch (e) {
            error.ParseZon => {
                std.debug.print("[Error] Could not parse config file: unknown option.\n", .{});
                return;
            },
            error.OutOfMemory => return e,
        }
    };

    program.model.config = parsed_config;

    try program.run();
}
