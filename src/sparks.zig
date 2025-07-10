const std = @import("std");

pub fn Sparkline(comptime T: type) type {
    return struct {
        values: []const T,

        pub fn init(values: []const T) @This() {
            return .{ .values = values };
        }

        pub fn render(self: @This(), writer: anytype) !void {
            const spark_chars = [_][]const u8{
                "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█",
            };

            if (self.values.len == 0) return;

            const min = std.mem.min(T, self.values);
            const max = std.mem.max(T, self.values);
            const range = max - min;

            for (self.values) |val| {
                const level = if (range == 0)
                    0
                else
                    @as(usize, ((val - min) * (spark_chars.len - 1)) / range);
                try writer.writeAll(spark_chars[level]);
            }
            try writer.writeByte('\n');
        }
    };
}
