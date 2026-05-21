const std = @import("std");
const zz = @import("zigzag");

pub const Model = struct {
    search_bar: zz.TextInput,
    // keymap: zz.KeyMap,
    result_list: zz.List([]const u8),
    focus_group: zz.FocusGroup(2),
    // focus_style: zz.FocusStyle,

    pub const Msg = union(enum) {
        key: zz.KeyEvent,
    };

    pub fn init(self: *Model, ctx: *zz.Context) zz.Cmd(Msg) {
        self.search_bar = zz.TextInput.init(ctx.persistent_allocator);
        self.search_bar.setPlaceholder("Search...");
        self.search_bar.setPrompt("> ");

        self.result_list = zz.List([]const u8).init(ctx.persistent_allocator);
        self.result_list.show_item_count = true;

        self.focus_group = .{};
        self.focus_group.add(&self.search_bar);
        self.focus_group.add(&self.result_list);
        self.focus_group.initFocus();

        return .none;
    }

    pub fn update(self: *Model, msg: Msg, _: *zz.Context) zz.Cmd(Msg) {
        switch (msg) {
            .key => |k| {
                switch (k.key) {
                    .escape => return .quit,
                    else => {},
                }

                if (self.focus_group.handleKey(k)) return .none;
                self.search_bar.handleKey(k);
                self.result_list.handleKey(k);
            },
        }

        return .none;
    }

    pub fn view(self: *Model, ctx: *const zz.Context) []const u8 {
        var title_style = zz.Style{};
        title_style = title_style.fg(zz.Color.gray(20));
        title_style = title_style.inline_style(true);
        const title = title_style.render(ctx.allocator, "znur") catch "znur";
        const title_width = zz.measure.width(title);

        const search_bar = self.search_bar.view(ctx.allocator) catch "Error";
        const search_bar_width = zz.measure.width(search_bar);

        const result_list = self.result_list.view(ctx.allocator) catch "Error";
        const result_list_width = zz.measure.width(result_list);

        var help_style = zz.Style{};
        help_style = help_style.fg(zz.Color.gray(12));
        help_style = help_style.inline_style(true);
        const help = help_style.render(
            ctx.allocator,
            "Tab: alternate between search bar and results",
        ) catch "";
        const help_width = zz.measure.width(help);

        const max_width = @max(title_width, @max(search_bar_width, @max(result_list_width, help_width)));
        const centered_title = zz.place.place(ctx.allocator, max_width, 1, .center, .top, title) catch title;
        const centered_help = zz.place.place(ctx.allocator, max_width, 1, .center, .top, help) catch help;

        const content = std.fmt.allocPrint(
            ctx.allocator,
            "{s}\n\n{s}\n{s}\n\n{s}",
            .{ centered_title, search_bar, result_list, centered_help },
        ) catch "Error";

        return zz.place.place(
            ctx.allocator,
            ctx.width,
            ctx.height,
            .center,
            .top,
            content,
        ) catch content;
    }

    pub fn deinit(self: *Model) void {
        self.search_bar.deinit();
        self.result_list.deinit();
    }
};
