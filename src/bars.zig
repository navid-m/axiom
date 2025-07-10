const std = @import("std");

const print = std.debug.print;

const Allocator = std.mem.Allocator;

pub const BarStyle = enum {
    ascii,
    unicode,
};

pub const BarChart = struct {
    labels: std.ArrayList([]const u8),
    values: std.ArrayList(u32),
    max_width: usize,
    style: BarStyle,

    pub fn init(allocator: Allocator, style: BarStyle, max_width: usize) BarChart {
        return BarChart{
            .labels = std.ArrayList([]const u8).init(allocator),
            .values = std.ArrayList(u32).init(allocator),
            .max_width = max_width,
            .style = style,
        };
    }

    pub fn deinit(self: *BarChart) void {
        self.labels.deinit();
        self.values.deinit();
    }

    pub fn addBar(self: *BarChart, label: []const u8, value: u32) !void {
        try self.labels.append(label);
        try self.values.append(value);
    }

    pub fn printChart(self: *BarChart) !void {
        if (self.values.items.len == 0) return;

        const max_val = blk: {
            var max: u32 = 0;
            for (self.values.items) |v| {
                if (v > max) max = v;
            }
            break :blk max;
        };

        for (self.labels.items, self.values.items) |label, value| {
            const bar_len =
                if (max_val > 0)
                    @as(usize, (value * self.max_width) / max_val)
                else
                    0;

            const bar_char: []const u8 = switch (self.style) {
                .ascii => "#",
                .unicode => "█",
            };
            print("{s: <12} | ", .{label});
            for (0..bar_len) |_| {
                print("{s}", .{bar_char});
            }
            print(" ({d})\n", .{value});
        }
    }
};
