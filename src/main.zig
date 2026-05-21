const std = @import("std");
const apps = @import("apps");
const zz = @import("zigzag");
const tui = @import("tui.zig");

pub fn main(init: std.process.Init) !void {
    // var aa = std.heap.ArenaAllocator.init(init.gpa);
    // const allocator = aa.allocator();
    // defer aa.deinit();

    // var stdout_buf: [1024]u8 = undefined;
    // var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    // const stdout = &stdout_writer.interface;

    // const finded_apps = try apps.find(allocator, init.io, init.environ_map);
    // const finded_apps_names = try apps.get_apps_names(allocator, finded_apps);

    // for (finded_apps_names) |name| {
    //     try stdout.print("{s}\n", .{name});
    // }

    // try stdout.flush();
    var program = zz.Program(tui.Model).init(init.gpa, init.io, init.environ_map);
    defer program.deinit();

    try program.run();
}
