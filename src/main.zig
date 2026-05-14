const std = @import("std");
const apps = @import("applications");

pub fn main(init: std.process.Init) !void {
    var alloc_buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_buf);
    const alloc = fba.allocator();
    _ = try apps.find(alloc, init.io, init.environ_map);
    _ = init.io;
}
