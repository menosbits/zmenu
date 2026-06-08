const std = @import("std");
const apps = @import("apps.zig");

pub fn log(io: std.Io, app: apps.Application) !void {
    const path = "/tmp/.zmenu_log";

    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);

    var buffer: [2048]u8 = undefined;
    var file_writer = file.writer(io, &buffer);
    const writer_interface = &file_writer.interface;

    try writer_interface.print("path: {s}\ncmd: {s}\nterm: {}\n", .{
        app.path,
        app.command,
        app.terminal,
    });
    try writer_interface.flush();
}
