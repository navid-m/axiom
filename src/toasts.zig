const std = @import("std");
const builtin = @import("builtin");
const colors = @import("colors.zig");

const Color = colors.Color;
const print = std.debug.print;

/// ANSI color codes for terminal output
///
/// Toast notification types
pub const ToastType = enum {
    info,
    success,
    warning,
    err,

    pub fn getColor(self: ToastType) []const u8 {
        return switch (self) {
            .info => Color.blue,
            .success => Color.green,
            .warning => Color.yellow,
            .err => Color.red,
        };
    }

    pub fn getIcon(self: ToastType) []const u8 {
        return switch (self) {
            .info => "ℹ",
            .success => "✓",
            .warning => "⚠",
            .err => "✗",
        };
    }

    pub fn getLabel(self: ToastType) []const u8 {
        return switch (self) {
            .info => "INFO",
            .success => "SUCCESS",
            .warning => "WARNING",
            .err => "ERROR",
        };
    }
};

/// The toast configuration
pub const Toast = struct {
    message: []const u8,
    toast_type: ToastType,
    show_icon: bool,
    show_timestamp: bool,
    width: ?usize,

    pub fn init(message: []const u8, toast_type: ToastType) Toast {
        return Toast{
            .message = message,
            .toast_type = toast_type,
            .show_icon = true,
            .show_timestamp = false,
            .width = null,
        };
    }

    pub fn withIcon(self: Toast, showx: bool) Toast {
        var toast = self;
        toast.show_icon = showx;
        return toast;
    }

    pub fn withTimestamp(self: Toast, showx: bool) Toast {
        var toast = self;
        toast.show_timestamp = showx;
        return toast;
    }

    pub fn withWidth(self: Toast, width: usize) Toast {
        var toast = self;
        toast.width = width;
        return toast;
    }

    fn stripAnsiAndCount(input: []const u8, allocator: std.mem.Allocator) !struct {
        clean: []const u8,
        display_width: usize,
    } {
        var clean_buf = std.ArrayList(u8).init(allocator);
        var i: usize = 0;
        while (i < input.len) {
            if (input[i] == '\x1B' and i + 1 < input.len and input[i + 1] == '[') {
                i += 2;
                while (i < input.len and (input[i] < 0x40 or input[i] > 0x7E)) {
                    i += 1;
                }
                if (i < input.len) i += 1;
            } else {
                try clean_buf.append(input[i]);
                i += 1;
            }
        }
        const clean = clean_buf.items;
        const display_width = try std.unicode.utf8CountCodepoints(clean);
        return .{ .clean = clean, .display_width = display_width };
    }

    pub fn show(self: Toast, allocator: std.mem.Allocator) !void {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
        }

        const color = self.toast_type.getColor();
        const icon = if (self.show_icon) self.toast_type.getIcon() else "";
        const label = self.toast_type.getLabel();

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();
        var content = std.ArrayList(u8).init(arena_allocator);
        defer content.deinit();

        if (self.show_icon) {
            try content.appendSlice(icon);
            try content.appendSlice(" ");
        }

        try content.appendSlice(label);
        try content.appendSlice(": ");
        try content.appendSlice(self.message);

        if (self.show_timestamp) {
            const timestamp = std.time.timestamp();
            const time_str = try std.fmt.allocPrint(arena_allocator, " [{}]", .{timestamp});
            try content.appendSlice(time_str);
        }

        const final_content = content.items;
        const visual_content = try stripAnsiAndCount(final_content, arena_allocator);
        const visual_len = visual_content.display_width;
        const content_width = if (self.width) |w| @max(w, visual_len + 4) else visual_len + 4;
        const padding = content_width - visual_len - 2;
        const left_pad = padding / 2;
        const right_pad = padding - left_pad;

        print("{s}{s}┌", .{ color, Color.bold });
        for (0..content_width - 2) |_| {
            print("─", .{});
        }
        print("┐{s}\n", .{Color.reset});

        print("{s}{s}│", .{ color, Color.bold });
        for (0..left_pad) |_| {
            print(" ", .{});
        }
        print("{s}{s}{s}", .{ Color.reset, color, final_content });
        for (0..right_pad) |_| {
            print(" ", .{});
        }
        print("{s}{s}│{s}\n", .{ Color.reset, color, Color.reset });
        print("{s}{s}└", .{ color, Color.bold });
        for (0..content_width - 2) |_| {
            print("─", .{});
        }
        print("┘{s}\n", .{Color.reset});
    }
};

const Allocator = std.mem.Allocator;

pub fn showInfo(allocator: Allocator, message: []const u8) !void {
    const toast = Toast.init(message, .info);
    try toast.show(allocator);
}

pub fn showSuccess(allocator: Allocator, message: []const u8) !void {
    const toast = Toast.init(message, .success);
    try toast.show(allocator);
}

pub fn showWarning(allocator: Allocator, message: []const u8) !void {
    const toast = Toast.init(message, .warning);
    try toast.show(allocator);
}

pub fn showError(allocator: Allocator, message: []const u8) !void {
    const toast = Toast.init(message, .err);
    try toast.show(allocator);
}
