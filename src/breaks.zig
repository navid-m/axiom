const std = @import("std");
const colors = @import("colors.zig");

const Color = colors.Color;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const BreakdownSegment = struct {
    label: []const u8,
    value: f64,
    color: ?[]const u8,
    percentage: f64,
};

pub const BreakdownStyle = enum {
    ascii,
    unicode,
    block,
    rounded,
    minimal,
};

pub const BreakdownChart = struct {
    allocator: Allocator,
    segments: ArrayList(BreakdownSegment),
    style: BreakdownStyle,
    title: ?[]const u8,
    width: u32,
    show_percentages: bool,
    show_values: bool,
    show_legend: bool,
    min_segment_width: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, style: BreakdownStyle, width: u32) Self {
        return Self{
            .allocator = allocator,
            .segments = ArrayList(BreakdownSegment).init(allocator),
            .style = style,
            .title = null,
            .width = width,
            .show_percentages = true,
            .show_values = false,
            .show_legend = true,
            .min_segment_width = 1,
        };
    }

    pub fn deinit(self: *Self) void {
        self.segments.deinit();
    }

    pub fn addSegment(self: *Self, label: []const u8, value: f64, color: ?[]const u8) !void {
        const segment = BreakdownSegment{
            .label = label,
            .value = value,
            .color = color,
            .percentage = 0.0,
        };
        try self.segments.append(segment);
    }

    pub fn withTitle(self: Self, title: []const u8) Self {
        var result = self;
        result.title = title;
        return result;
    }

    pub fn withPercentages(self: Self, show: bool) Self {
        var result = self;
        result.show_percentages = show;
        return result;
    }

    pub fn withValues(self: Self, show: bool) Self {
        var result = self;
        result.show_values = show;
        return result;
    }

    pub fn withLegend(self: Self, show: bool) Self {
        var result = self;
        result.show_legend = show;
        return result;
    }

    pub fn withMinSegmentWidth(self: Self, width: u32) Self {
        var result = self;
        result.min_segment_width = width;
        return result;
    }

    fn calculatePercentages(self: *Self) void {
        var total: f64 = 0.0;
        for (self.segments.items) |segment| {
            total += segment.value;
        }

        if (total > 0.0) {
            for (self.segments.items) |*segment| {
                segment.percentage = (segment.value / total) * 100.0;
            }
        }
    }

    fn getSegmentChar(self: Self) []const u8 {
        return switch (self.style) {
            .ascii => "=",
            .unicode => "█",
            .block => "█",
            .rounded => "█",
            .minimal => "▬",
        };
    }

    fn getLegendChar(self: Self) []const u8 {
        return switch (self.style) {
            .ascii => "o",
            .unicode => "●",
            .block => "●",
            .rounded => "●",
            .minimal => "•",
        };
    }

    fn getSegmentColor(self: Self, segment_index: usize) ?[]const u8 {
        const default_colors = [_][]const u8{ Color.red, Color.green, Color.blue, Color.yellow, Color.magenta, Color.cyan, Color.white };

        if (segment_index < self.segments.items.len) {
            if (self.segments.items[segment_index].color) |color| {
                return color;
            }
        }

        return default_colors[segment_index % default_colors.len];
    }

    pub fn printChart(self: *Self) !void {
        if (self.segments.items.len == 0) {
            std.debug.print("No segments to display\n");
            return;
        }

        self.calculatePercentages();

        if (self.title) |title| {
            std.debug.print("{s}\n", .{title});
        }

        try self.printBreakdownBar();

        if (self.show_legend) {
            try self.printLegend();
        }

        std.debug.print("\n");
    }

    fn printBreakdownBar(self: *Self) !void {
        _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);

        self.calculatePercentages();

        const bar_width = self.width;

        var segment_widths = try self.allocator.alloc(u32, self.segments.items.len);
        defer self.allocator.free(segment_widths);
        var remaining_width = bar_width;

        for (self.segments.items, 0..) |segment, i| {
            if (i == self.segments.items.len - 1) {
                segment_widths[i] = remaining_width;
            } else {
                const ideal_width = @as(u32, @intFromFloat(@round((segment.percentage / 100.0) * @as(f64, @floatFromInt(bar_width)))));
                const actual_width = @max(self.min_segment_width, ideal_width);
                segment_widths[i] = @min(actual_width, remaining_width);
                remaining_width -= segment_widths[i];
            }
        }

        for (self.segments.items, 0..) |_, i| {
            const segment_char = self.getSegmentChar();
            const color = self.getSegmentColor(i);

            if (color) |c| {
                std.debug.print("{s}", .{c});
            }

            for (0..segment_widths[i]) |_| {
                std.debug.print("{s}", .{segment_char});
            }

            if (color) |_| {
                std.debug.print("{s}", .{Color.reset});
            }
        }
        std.debug.print("\n", .{});
    }

    fn printLegend(self: *Self) !void {
        _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);

        self.calculatePercentages();

        std.debug.print("\nLegend:\n", .{});
        for (self.segments.items, 0..) |segment, i| {
            const color = self.getSegmentColor(i);
            const legend_char = self.getLegendChar();

            if (color) |c| {
                std.debug.print("{s}", .{c});
            }

            std.debug.print("{s}", .{legend_char});

            if (color) |_| {
                std.debug.print("{s}", .{Color.reset});
            }

            std.debug.print(" {s}", .{segment.label});

            if (self.show_percentages) {
                std.debug.print(" ({d:.1}%)", .{segment.percentage});
            }

            if (self.show_values) {
                std.debug.print(" [{d:.2}]", .{segment.value});
            }

            std.debug.print("\n", .{});
        }
    }

    pub fn printStatistics(self: *Self) !void {
        if (self.segments.items.len == 0) return;

        self.calculatePercentages();

        var total: f64 = 0.0;
        for (self.segments.items) |segment| {
            total += segment.value;
        }

        std.debug.print("Statistics:\n");
        std.debug.print("  Total: {d:.2}\n", .{total});
        std.debug.print("  Segments: {d}\n", .{self.segments.items.len});

        var largest_idx: usize = 0;
        for (self.segments.items, 0..) |segment, i| {
            if (segment.value > self.segments.items[largest_idx].value) {
                largest_idx = i;
            }
        }

        std.debug.print("  Largest: {s} ({d:.1}%)\n", .{ self.segments.items[largest_idx].label, self.segments.items[largest_idx].percentage });
    }
};

pub fn createBreakdown(allocator: Allocator, labels: []const []const u8, values: []const f64, style: BreakdownStyle, width: u32) !BreakdownChart {
    var chart = BreakdownChart.init(allocator, style, width);

    for (labels, 0..) |label, i| {
        if (i < values.len) {
            try chart.addSegment(label, values[i], null);
        }
    }

    return chart;
}

const testing = std.testing;

test "breakdown chart basic functionality" {
    const allocator = std.heap.page_allocator;
    var chart = BreakdownChart.init(allocator, .unicode, 40);
    defer chart.deinit();

    try chart.addSegment("Frontend", 45.0, null);
    try chart.addSegment("Backend", 30.0, null);
    try chart.addSegment("Database", 15.0, null);
    try chart.addSegment("Other", 10.0, null);
    try testing.expect(chart.segments.items.len == 4);
    try chart.printBreakdownBar();
    try chart.printLegend();
}

test "simple breakdown creation" {
    const allocator = std.heap.page_allocator;
    const labels = [_][]const u8{ "JavaScript", "TypeScript", "CSS", "HTML" };
    const values = [_]f64{ 45.2, 28.7, 16.1, 10.0 };

    var chart = try createBreakdown(allocator, &labels, &values, .unicode, 50);
    defer chart.deinit();

    try testing.expect(chart.segments.items.len == 4);
}
