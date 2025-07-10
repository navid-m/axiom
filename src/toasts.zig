const std = @import("std");
const builtin = @import("builtin");
const colors = @import("colors.zig");
const ansi = @import("ansi.zig");

const print = std.debug.print;
const stripAnsiAndCount = ansi.stripAnsiAndCount;

const Allocator = std.mem.Allocator;
const Color = colors.Color;

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
