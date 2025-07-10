const std = @import("std");
const builtin = @import("builtin");

const testing = std.testing;
const print = std.debug.print;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

/// Denotes the table drawing characters
const TableChars = struct {
    const BoxChars = struct {
        top_left: []const u8,
        top_right: []const u8,
        bottom_left: []const u8,
        bottom_right: []const u8,
        horizontal: []const u8,
        vertical: []const u8,
        cross: []const u8,
        tee_down: []const u8,
        tee_up: []const u8,
        tee_left: []const u8,
        tee_right: []const u8,
    };

    const ascii = BoxChars{
        .top_left = "+",
        .top_right = "+",
        .bottom_left = "+",
        .bottom_right = "+",
        .horizontal = "-",
        .vertical = "|",
        .cross = "+",
        .tee_down = "+",
        .tee_up = "+",
        .tee_left = "+",
        .tee_right = "+",
    };

    const unicode = BoxChars{
        .top_left = "┌",
        .top_right = "┐",
        .bottom_left = "└",
        .bottom_right = "┘",
        .horizontal = "─",
        .vertical = "│",
        .cross = "┼",
        .tee_down = "┬",
        .tee_up = "┴",
        .tee_left = "┤",
        .tee_right = "├",
    };

    const double_line = BoxChars{
        .top_left = "╔",
        .top_right = "╗",
        .bottom_left = "╚",
        .bottom_right = "╝",
        .horizontal = "═",
        .vertical = "║",
        .cross = "╬",
        .tee_down = "╦",
        .tee_up = "╩",
        .tee_left = "╣",
        .tee_right = "╠",
    };

    const rounded = BoxChars{
        .top_left = "╭",
        .top_right = "╮",
        .bottom_left = "╰",
        .bottom_right = "╯",
        .horizontal = "─",
        .vertical = "│",
        .cross = "┼",
        .tee_down = "┬",
        .tee_up = "┴",
        .tee_left = "┤",
        .tee_right = "├",
    };
};

/// The table content alignment options
pub const Alignment = enum {
    left,
    center,
    right,
};

/// The table style options
pub const TableStyle = enum {
    ascii,
    unicode,
    double_line,
    rounded,
};

/// The overall column configuration
pub const Column = struct {
    header: []const u8,
    width: usize,
    alignment: Alignment,

    pub fn init(header: []const u8, width: usize, alignment: Alignment) Column {
        return Column{
            .header = header,
            .width = width,
            .alignment = alignment,
        };
    }
};

/// The table itself
pub const Table = struct {
    allocator: Allocator,
    columns: ArrayList(Column),
    rows: ArrayList(ArrayList([]const u8)),
    style: TableStyle,
    has_header: bool,

    pub fn init(allocator: Allocator, style: TableStyle) Table {
        return Table{
            .allocator = allocator,
            .columns = ArrayList(Column).init(allocator),
            .rows = ArrayList(ArrayList([]const u8)).init(allocator),
            .style = style,
            .has_header = false,
        };
    }

    pub fn deinit(self: *Table) void {
        for (self.rows.items) |row| {
            row.deinit();
        }
        self.rows.deinit();
        self.columns.deinit();
    }

    pub fn addColumn(self: *Table, header: []const u8, width: usize, alignment: Alignment) !void {
        try self.columns.append(Column.init(header, width, alignment));
        self.has_header = true;
    }

    pub fn addRow(self: *Table, row_data: []const []const u8) !void {
        var row = ArrayList([]const u8).init(self.allocator);
        for (row_data) |cell| {
            try row.append(cell);
        }
        try self.rows.append(row);
    }

    fn getBoxChars(self: *const Table) TableChars.BoxChars {
        return switch (self.style) {
            .ascii => TableChars.ascii,
            .unicode => TableChars.unicode,
            .double_line => TableChars.double_line,
            .rounded => TableChars.rounded,
        };
    }

    fn padString(_: *const Table, allocator: Allocator, text: []const u8, width: usize, alignment: Alignment) ![]u8 {
        if (text.len >= width) {
            return try allocator.dupe(u8, text[0..width]);
        }

        const padding = width - text.len;
        var result = try allocator.alloc(u8, width);

        switch (alignment) {
            .left => {
                @memcpy(result[0..text.len], text);
                @memset(result[text.len..], ' ');
            },
            .right => {
                @memset(result[0..padding], ' ');
                @memcpy(result[padding..], text);
            },
            .center => {
                const left_pad = padding / 2;
                @memset(result[0..left_pad], ' ');
                @memcpy(result[left_pad .. left_pad + text.len], text);
                @memset(result[left_pad + text.len ..], ' ');
            },
        }

        return result;
    }

    fn printHorizontalLine(self: *const Table, line_type: enum { top, middle, bottom }) void {
        const chars = self.getBoxChars();

        const left_char = switch (line_type) {
            .top => chars.top_left,
            .middle => chars.tee_right,
            .bottom => chars.bottom_left,
        };

        const right_char = switch (line_type) {
            .top => chars.top_right,
            .middle => chars.tee_left,
            .bottom => chars.bottom_right,
        };

        const junction_char = switch (line_type) {
            .top => chars.tee_down,
            .middle => chars.cross,
            .bottom => chars.tee_up,
        };

        print("{s}", .{left_char});

        for (self.columns.items, 0..) |column, i| {
            for (0..column.width + 2) |_| {
                print("{s}", .{chars.horizontal});
            }

            if (i < self.columns.items.len - 1) {
                print("{s}", .{junction_char});
            } else {
                print("{s}", .{right_char});
            }
        }
        print("\n", .{});
    }

    pub fn printTable(self: *const Table) !void {
        if (self.columns.items.len == 0) {
            print("Empty table\n", .{});
            return;
        }

        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
        }

        const chars = self.getBoxChars();
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        self.printHorizontalLine(.top);

        if (self.has_header) {
            print("{s}", .{chars.vertical});
            for (self.columns.items) |column| {
                const padded_header = try self.padString(arena_allocator, column.header, column.width, column.alignment);
                print(" {s} ", .{padded_header});
                print("{s}", .{chars.vertical});
            }

            print("\n", .{});

            self.printHorizontalLine(.middle);
        }

        for (self.rows.items) |row| {
            print("{s}", .{chars.vertical});
            for (self.columns.items, 0..) |column, i| {
                const cell_data = if (i < row.items.len) row.items[i] else "";
                const padded_cell = try self.padString(arena_allocator, cell_data, column.width, column.alignment);
                print(" {s} ", .{padded_cell});
                print("{s}", .{chars.vertical});
            }
            print("\n", .{});
        }

        self.printHorizontalLine(.bottom);
    }
};

fn findColumnIndex(headers: []const []const u8, header: []const u8) ?usize {
    for (headers, 0..) |h, i| {
        if (std.mem.eql(u8, h, header)) {
            return i;
        }
    }
    return null;
}

pub fn createSimpleTable(allocator: Allocator, headers: []const []const u8, rows: []const []const []const u8) !Table {
    var table = Table.init(allocator, .unicode);

    for (headers) |header| {
        var max_width = header.len;
        const col_index = findColumnIndex(headers, header) orelse 0;
        for (rows) |row| {
            if (col_index < row.len and row[col_index].len > max_width) {
                max_width = row[col_index].len;
            }
        }

        try table.addColumn(header, @max(max_width, 5), .left);
    }

    for (rows) |row| {
        try table.addRow(row);
    }

    return table;
}

pub fn createSimpleTableWithStyle(allocator: Allocator, headers: []const []const u8, rows: []const []const []const u8, style: TableStyle) !Table {
    var table = Table.init(allocator, style);

    for (headers) |header| {
        var max_width = header.len;
        const col_index = findColumnIndex(headers, header) orelse 0;
        for (rows) |row| {
            if (col_index < row.len and row[col_index].len > max_width) {
                max_width = row[col_index].len;
            }
        }

        try table.addColumn(header, @max(max_width, 5), .left);
    }

    for (rows) |row| {
        try table.addRow(row);
    }

    return table;
}

test "table creation and basic functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var table = Table.init(allocator, .ascii);
    defer table.deinit();

    try table.addColumn("Name", 10, .left);
    try table.addColumn("Age", 5, .right);
    try table.addColumn("City", 12, .center);

    try table.addRow(&[_][]const u8{ "Alice", "25", "New York" });
    try table.addRow(&[_][]const u8{ "Bob", "30", "Los Angeles" });

    try testing.expect(table.columns.items.len == 3);
    try testing.expect(table.rows.items.len == 2);
}

test "rounded table style" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var table = Table.init(allocator, .rounded);
    defer table.deinit();

    try table.addColumn("Name", 10, .left);
    try table.addColumn("Age", 5, .right);
    try table.addColumn("City", 12, .center);

    try table.addRow(&[_][]const u8{ "Alice", "25", "New York" });
    try table.addRow(&[_][]const u8{ "Bob", "30", "Los Angeles" });

    try testing.expect(table.columns.items.len == 3);
    try testing.expect(table.rows.items.len == 2);
}

test "simple table creation" {
    const allocator = std.heap.page_allocator;
    const headers = [_][]const u8{ "Product", "Price", "Stock" };
    const rows = [_][]const []const u8{
        &[_][]const u8{ "Widget", "$10.99", "50" },
        &[_][]const u8{ "Gadget", "$25.50", "23" },
        &[_][]const u8{ "Tool", "$15.75", "100" },
    };

    var table = try createSimpleTable(allocator, &headers, &rows);
    defer table.deinit();

    try testing.expect(table.columns.items.len == 3);
    try testing.expect(table.rows.items.len == 3);

    print("=== ASCII Table Example ===\n", .{});
    var ascii_table = Table.init(allocator, .ascii);
    defer ascii_table.deinit();

    try ascii_table.addColumn("Name", 12, .left);
    try ascii_table.addColumn("Age", 5, .right);
    try ascii_table.addColumn("Department", 15, .center);
    try ascii_table.addColumn("Salary", 10, .right);
    try ascii_table.addRow(&[_][]const u8{ "Alice Johnson", "28", "Engineering", "$75,000" });
    try ascii_table.addRow(&[_][]const u8{ "Bob Smith", "35", "Marketing", "$65,000" });
    try ascii_table.addRow(&[_][]const u8{ "Carol Davis", "42", "Finance", "$80,000" });
    try ascii_table.printTable();

    print("\n=== Unicode Table Example ===\n", .{});
    const headersa = [_][]const u8{ "Product", "Price", "Stock", "Category" };
    const rowsa = [_][]const []const u8{
        &[_][]const u8{ "Laptop", "$899.99", "15", "Electronics" },
        &[_][]const u8{ "Mouse", "$29.99", "50", "Accessories" },
        &[_][]const u8{ "Keyboard", "$79.99", "25", "Accessories" },
        &[_][]const u8{ "Monitor", "$299.99", "8", "Electronics" },
    };

    var unicode_table = try createSimpleTable(allocator, &headersa, &rowsa);
    defer unicode_table.deinit();

    try unicode_table.printTable();

    print("\n=== Double Line Table Example ===\n", .{});
    var double_table = Table.init(allocator, .double_line);
    defer double_table.deinit();

    try double_table.addColumn("Language", 10, .left);
    try double_table.addColumn("Year", 6, .center);
    try double_table.addColumn("Type", 12, .left);
    try double_table.addRow(&[_][]const u8{ "Zig", "2016", "Systems" });
    try double_table.addRow(&[_][]const u8{ "Rust", "2010", "Systems" });
    try double_table.addRow(&[_][]const u8{ "Go", "2009", "General" });
    try double_table.printTable();

    print("\n=== Rounded Table Example ===\n", .{});
    var rounded_table = Table.init(allocator, .rounded);
    defer rounded_table.deinit();

    try rounded_table.addColumn("Framework", 12, .left);
    try rounded_table.addColumn("Stars", 8, .right);
    try rounded_table.addColumn("Language", 10, .center);
    try rounded_table.addRow(&[_][]const u8{ "React", "220k", "JavaScript" });
    try rounded_table.addRow(&[_][]const u8{ "Vue", "206k", "JavaScript" });
    try rounded_table.addRow(&[_][]const u8{ "Angular", "93k", "TypeScript" });
    try rounded_table.printTable();

    print("\n=== Rounded Table  ===\n", .{});
    const tech_headers = [_][]const u8{ "Technology", "Type", "Popularity" };
    const tech_rows = [_][]const []const u8{
        &[_][]const u8{ "Docker", "Container", "Very High" },
        &[_][]const u8{ "Kubernetes", "Orchestration", "High" },
        &[_][]const u8{ "GraphQL", "API", "Medium" },
    };

    var rounded_simple_table = try createSimpleTableWithStyle(allocator, &tech_headers, &tech_rows, .rounded);
    defer rounded_simple_table.deinit();

    try rounded_simple_table.printTable();
}
