const std = @import("std");
const colors = @import("colors.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const LineStyle = enum {
    ascii,
    unicode,
    smooth,
};

pub const LinePoint = struct {
    x: f64,
    y: f64,
    label: ?[]const u8 = null,
};

pub const LineChart = struct {
    allocator: Allocator,
    points: ArrayList(LinePoint),
    style: LineStyle,
    width: u32,
    height: u32,
    title: ?[]const u8,
    x_label: ?[]const u8,
    y_label: ?[]const u8,
    color: ?colors.Color,
    show_grid: bool,
    show_values: bool,
    min_x: f64,
    max_x: f64,
    min_y: f64,
    max_y: f64,
    auto_scale: bool,

    const Self = @This();

    pub fn init(allocator: Allocator, style: LineStyle, width: u32, height: u32) Self {
        return Self{
            .allocator = allocator,
            .points = ArrayList(LinePoint).init(allocator),
            .style = style,
            .width = width,
            .height = height,
            .title = null,
            .x_label = null,
            .y_label = null,
            .color = null,
            .show_grid = false,
            .show_values = false,
            .min_x = 0,
            .max_x = 0,
            .min_y = 0,
            .max_y = 0,
            .auto_scale = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.points.deinit();
    }

    pub fn addPoint(self: *Self, x: f64, y: f64, label: ?[]const u8) !void {
        try self.points.append(LinePoint{ .x = x, .y = y, .label = label });

        if (self.auto_scale) {
            self.updateBounds();
        }
    }

    pub fn addPointsFromSlice(self: *Self, x_values: []const f64, y_values: []const f64) !void {
        if (x_values.len != y_values.len) {
            return error.MismatchedArrayLengths;
        }

        for (x_values, y_values) |x, y| {
            try self.addPoint(x, y, null);
        }
    }

    pub fn addPointsFromYValues(self: *Self, y_values: []const f64) !void {
        for (y_values, 0..) |y, i| {
            try self.addPoint(@as(f64, @floatFromInt(i)), y, null);
        }
    }

    pub fn withTitle(self: Self, title: []const u8) Self {
        var new_self = self;
        new_self.title = title;
        return new_self;
    }

    pub fn withLabels(self: Self, x_label: []const u8, y_label: []const u8) Self {
        var new_self = self;
        new_self.x_label = x_label;
        new_self.y_label = y_label;
        return new_self;
    }

    pub fn withColor(self: Self, color: colors.Color) Self {
        var new_self = self;
        new_self.color = color;
        return new_self;
    }

    pub fn withGrid(self: Self, show_grid: bool) Self {
        var new_self = self;
        new_self.show_grid = show_grid;
        return new_self;
    }

    pub fn withValues(self: Self, show_values: bool) Self {
        var new_self = self;
        new_self.show_values = show_values;
        return new_self;
    }

    pub fn setBounds(self: *Self, min_x: f64, max_x: f64, min_y: f64, max_y: f64) void {
        self.min_x = min_x;
        self.max_x = max_x;
        self.min_y = min_y;
        self.max_y = max_y;
        self.auto_scale = false;
    }

    fn updateBounds(self: *Self) void {
        if (self.points.items.len == 0) return;

        var first = true;
        for (self.points.items) |point| {
            if (first) {
                self.min_x = point.x;
                self.max_x = point.x;
                self.min_y = point.y;
                self.max_y = point.y;
                first = false;
            } else {
                self.min_x = @min(self.min_x, point.x);
                self.max_x = @max(self.max_x, point.x);
                self.min_y = @min(self.min_y, point.y);
                self.max_y = @max(self.max_y, point.y);
            }
        }

        const x_range = self.max_x - self.min_x;
        const y_range = self.max_y - self.min_y;

        if (x_range > 0) {
            const x_padding = x_range * 0.05;
            self.min_x -= x_padding;
            self.max_x += x_padding;
        }

        if (y_range > 0) {
            const y_padding = y_range * 0.05;
            self.min_y -= y_padding;
            self.max_y += y_padding;
        }
    }

    fn mapToScreen(self: Self, x: f64, y: f64) struct { x: u32, y: u32 } {
        const x_ratio = if (self.max_x > self.min_x)
            (x - self.min_x) / (self.max_x - self.min_x)
        else
            0.5;

        const y_ratio = if (self.max_y > self.min_y)
            (y - self.min_y) / (self.max_y - self.min_y)
        else
            0.5;

        const screen_x = @as(u32, @intFromFloat(x_ratio * @as(f64, @floatFromInt(self.width - 1))));
        const screen_y = @as(u32, @intFromFloat((1.0 - y_ratio) * @as(f64, @floatFromInt(self.height - 1))));

        return .{ .x = screen_x, .y = screen_y };
    }

    fn getLineChar(self: Self, direction: u8) []const u8 {
        return switch (self.style) {
            .ascii => switch (direction) {
                0 => "-",
                1 => "|",
                2 => "/",
                3 => "\\",
                else => "*",
            },
            .unicode => switch (direction) {
                0 => "─",
                1 => "│",
                2 => "╱",
                3 => "╲",
                else => "●",
            },
            .smooth => switch (direction) {
                0 => "━",
                1 => "┃",
                2 => "╱",
                3 => "╲",
                else => "●",
            },
        };
    }

    fn getGridChar(self: Self, is_horizontal: bool) []const u8 {
        return switch (self.style) {
            .ascii => if (is_horizontal) "-" else "|",
            .unicode => if (is_horizontal) "─" else "│",
            .smooth => if (is_horizontal) "┄" else "┆",
        };
    }

    pub fn printChart(self: *Self) !void {
        if (self.points.items.len == 0) {
            std.debug.print("No data points to display\n", .{});
            return;
        }

        std.sort.heap(LinePoint, self.points.items, {}, struct {
            fn lessThan(context: void, a: LinePoint, b: LinePoint) bool {
                _ = context;
                return a.x < b.x;
            }
        }.lessThan);

        const canvas = try self.allocator.alloc([][]const u8, self.height);
        defer self.allocator.free(canvas);

        for (canvas) |*row| {
            row.* = try self.allocator.alloc([]const u8, self.width);
            for (row.*) |*cell| {
                cell.* = " ";
            }
        }
        defer for (canvas) |row| {
            self.allocator.free(row);
        };

        if (self.show_grid) {
            try self.drawGrid(canvas);
        }

        try self.drawLine(canvas);
        try self.drawPoints(canvas);

        if (self.title) |title| {
            const padding = (self.width - title.len) / 2;
            for (0..padding) |_| std.debug.print(" ", .{});
            std.debug.print("{s}\n", .{title});
        }

        for (canvas) |row| {
            for (row) |cell| {
                std.debug.print("{s}", .{cell});
            }
            std.debug.print("\n", .{});
        }

        if (self.x_label) |x_label| {
            const padding = (self.width - x_label.len) / 2;
            for (0..padding) |_| std.debug.print(" ", .{});
            std.debug.print("{s}\n", .{x_label});
        }

        if (self.y_label) |y_label| {
            std.debug.print("{s}\n", .{y_label});
        }
    }

    fn drawGrid(self: Self, canvas: [][][]const u8) !void {
        var y: u32 = 0;
        while (y < self.height) : (y += self.height / 5) {
            if (y < self.height) {
                for (0..self.width) |x| {
                    canvas[y][x] = self.getGridChar(true);
                }
            }
        }

        var x: u32 = 0;
        while (x < self.width) : (x += self.width / 5) {
            if (x < self.width) {
                for (0..self.height) |y_idx| {
                    canvas[y_idx][x] = self.getGridChar(false);
                }
            }
        }
    }

    fn drawLine(self: Self, canvas: [][][]const u8) !void {
        if (self.points.items.len < 2) return;

        for (0..self.points.items.len - 1) |i| {
            const p1 = self.points.items[i];
            const p2 = self.points.items[i + 1];

            const screen1 = self.mapToScreen(p1.x, p1.y);
            const screen2 = self.mapToScreen(p2.x, p2.y);

            try self.drawLineSegment(canvas, screen1.x, screen1.y, screen2.x, screen2.y);
        }
    }

    fn drawLineSegment(self: Self, canvas: [][][]const u8, x1: u32, y1: u32, x2: u32, y2: u32) !void {
        const dx = if (x2 > x1) @as(i32, @intCast(x2 - x1)) else -@as(i32, @intCast(x1 - x2));
        const dy = if (y2 > y1) @as(i32, @intCast(y2 - y1)) else -@as(i32, @intCast(y1 - y2));

        const steps = @max(@abs(dx), @abs(dy));
        if (steps == 0) return;

        const x_inc = @as(f64, @floatFromInt(dx)) / @as(f64, @floatFromInt(steps));
        const y_inc = @as(f64, @floatFromInt(dy)) / @as(f64, @floatFromInt(steps));

        var x = @as(f64, @floatFromInt(x1));
        var y = @as(f64, @floatFromInt(y1));

        for (0..@as(u32, @intCast(steps + 1))) |_| {
            const px = @as(u32, @intFromFloat(x));
            const py = @as(u32, @intFromFloat(y));

            if (px < self.width and py < self.height) {
                var direction: u8 = 0;
                if (@abs(dx) > @abs(dy)) {
                    direction = 0;
                } else if (@abs(dy) > @abs(dx)) {
                    direction = 1;
                } else if ((dx > 0 and dy < 0) or (dx < 0 and dy > 0)) {
                    direction = 2;
                } else {
                    direction = 3;
                }

                canvas[py][px] = self.getLineChar(direction);
            }

            x += x_inc;
            y += y_inc;
        }
    }

    fn drawPoints(self: Self, canvas: [][][]const u8) !void {
        const point_char = switch (self.style) {
            .ascii => "*",
            .unicode => "●",
            .smooth => "●",
        };

        for (self.points.items) |point| {
            const screen = self.mapToScreen(point.x, point.y);
            if (screen.x < self.width and screen.y < self.height) {
                canvas[screen.y][screen.x] = point_char;
            }
        }
    }

    pub fn printStatistics(self: Self) !void {
        if (self.points.items.len == 0) {
            std.debug.print("No data points for statistics\n", .{});
            return;
        }

        var sum_y: f64 = 0;
        var min_y = self.points.items[0].y;
        var max_y = self.points.items[0].y;

        for (self.points.items) |point| {
            sum_y += point.y;
            min_y = @min(min_y, point.y);
            max_y = @max(max_y, point.y);
        }

        const mean = sum_y / @as(f64, @floatFromInt(self.points.items.len));
        const range = max_y - min_y;

        std.debug.print("\nLine Chart Statistics:\n", .{});
        std.debug.print("Points: {d}\n", .{self.points.items.len});
        std.debug.print("Y Range: {d:.2} to {d:.2}\n", .{ min_y, max_y });
        std.debug.print("Y Mean: {d:.2}\n", .{mean});
        std.debug.print("Y Range: {d:.2}\n", .{range});
    }
};

pub fn createSimpleLineChart(allocator: Allocator, y_values: []const f64, style: LineStyle) !LineChart {
    var chart = LineChart.init(allocator, style, 60, 20);
    try chart.addPointsFromYValues(y_values);
    return chart;
}

pub fn createLineChart(allocator: Allocator, x_values: []const f64, y_values: []const f64, style: LineStyle, width: u32, height: u32) !LineChart {
    var chart = LineChart.init(allocator, style, width, height);
    try chart.addPointsFromSlice(x_values, y_values);
    return chart;
}
