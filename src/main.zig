const std = @import("std");
const apps = @import("apps");
const zz = @import("zigzag");
const tui = @import("tui.zig");

pub fn main(init: std.process.Init) !void {
    var program = zz.Program(tui.Model).init(init.gpa, init.io, init.environ_map);
    program.model.env = init.environ_map;
    defer program.deinit();

    try program.run();
}
