const std = @import("std");

pub fn stripAnsiAndCount(input: []const u8, allocator: std.mem.Allocator) !struct {
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
