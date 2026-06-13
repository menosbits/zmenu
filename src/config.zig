const std = @import("std");

pub const Mode = enum {
    normal,
    dmenu,
};

pub const Message = struct {
    text: ?[]const u8,
};

pub const Config = struct {
    placeholder: []const u8 = "Search...",
    prompt: []const u8 = " ",
    mode: Mode = .normal,
    terminal: ?[]const u8 = null,
};
