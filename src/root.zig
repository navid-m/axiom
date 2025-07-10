const std = @import("std");
const builtin = @import("builtin");
const toasts = @import("toasts.zig");
const colors = @import("colors.zig");
const tables = @import("tables.zig");
const bars = @import("bars.zig");
const sparks = @import("sparks.zig");
const lines = @import("lines.zig");

pub const BarChart = bars.BarChart;
pub const BarStyle = bars.BarStyle;
pub const Table = tables.Table;
pub const TableColorTheme = tables.TableColorTheme;
pub const Toast = toasts.Toast;
pub const Color = colors.Color;
pub const Sparkline = sparks.Sparkline;
pub const LineChart = lines.LineChart;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const testing = std.testing;
const print = std.debug.print;

pub const showInfo = toasts.showInfo;
pub const showError = toasts.showError;
pub const showSuccess = toasts.showSuccess;
pub const showWarning = toasts.showWarning;
pub const createSimpleTable = tables.createSimpleTable;
pub const createSimpleTableWithStyle = tables.createSimpleTableWithStyle;
pub const createSimpleLineChart = lines.createSimpleLineChart;
pub const createLineChart = lines.createLineChart;

test "table creation and basic functionality" {
    var table = Table.init(std.heap.page_allocator, .ascii);
    defer table.deinit();

    try table.addColumn("Name", 10, .left);
    try table.addColumn("Age", 5, .right);
    try table.addColumn("City", 12, .center);
    try table.addRow(&[_][]const u8{ "Alice", "25", "New York" });
    try table.addRow(&[_][]const u8{ "Bob", "30", "Los Angeles" });
    try testing.expect(table.columns.items.len == 3);
    try testing.expect(table.rows.items.len == 2);
}

test "toast notifications" {
    const allocator = std.heap.page_allocator;

    try showInfo(allocator, "This is an info message");
    try showSuccess(allocator, "Operation completed successfully");
    try showWarning(allocator, "This is a warning message");
    try showError(allocator, "An error occurred");
}

test "colored tables and toasts" {
    const allocator = std.heap.page_allocator;

    try showInfo(allocator, "Starting table examples");

    const custom_toast = Toast.init("Custom toast with timestamp", .success)
        .withTimestamp(true)
        .withWidth(50);
    try custom_toast.show(allocator);

    var colored_table = Table.init(allocator, .unicode)
        .withColors(TableColorTheme.blue)
        .withAlternatingRows(true);
    defer colored_table.deinit();

    try colored_table.addColumn("Language", 12, .left);
    try colored_table.addColumn("Year", 6, .center);
    try colored_table.addColumn("Type", 12, .left);
    try colored_table.addColumn("Rating", 8, .right);
    try colored_table.addRow(&[_][]const u8{ "Zig", "2016", "Systems", "★★★☆☆" });
    try colored_table.addRow(&[_][]const u8{ "Rust", "2010", "Systems", "★☆☆☆☆" });
    try colored_table.addRow(&[_][]const u8{ "Go", "2009", "General", "★★★★☆" });
    try colored_table.addRow(&[_][]const u8{ "Python", "1991", "General", "★★★☆☆" });
    try colored_table.printTable();
    try showSuccess(allocator, "Table printed successfully");

    var green_table = Table.init(allocator, .rounded)
        .withColors(TableColorTheme.green);
    defer green_table.deinit();

    try green_table.addColumn("Status", 10, .left);
    try green_table.addColumn("Count", 8, .right);
    try green_table.addColumn("Percentage", 12, .center);
    try green_table.addRow(&[_][]const u8{ "Active", "150", "75%" });
    try green_table.addRow(&[_][]const u8{ "Inactive", "50", "25%" });
    try green_table.printTable();
    try showInfo(allocator, "All examples completed");
}

test "rounded table style" {
    var table = Table.init(std.heap.page_allocator, .rounded);
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

    print("ASCII Table\n", .{});
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

    print("\nUnicode Table Example\n", .{});
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

    print("\nDouble Line Table Example\n", .{});
    var double_table = Table.init(allocator, .double_line);
    defer double_table.deinit();

    try double_table.addColumn("Language", 10, .left);
    try double_table.addColumn("Year", 6, .center);
    try double_table.addColumn("Type", 12, .left);
    try double_table.addRow(&[_][]const u8{ "Zig", "2016", "Systems" });
    try double_table.addRow(&[_][]const u8{ "Rust", "2010", "Systems" });
    try double_table.addRow(&[_][]const u8{ "Go", "2009", "General" });
    try double_table.printTable();

    print("\nRounded Table Example\n", .{});
    var rounded_table = Table.init(allocator, .rounded);
    defer rounded_table.deinit();

    try rounded_table.addColumn("Framework", 12, .left);
    try rounded_table.addColumn("Stars", 8, .right);
    try rounded_table.addColumn("Language", 10, .center);
    try rounded_table.addRow(&[_][]const u8{ "React", "220k", "I" });
    try rounded_table.addRow(&[_][]const u8{ "Vue", "206k", "Hate" });
    try rounded_table.addRow(&[_][]const u8{ "Angular", "93k", "Frameworks" });
    try rounded_table.printTable();

    print("\nRounded Table Example II\n", .{});
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

test "bar chart basic display" {
    const allocator = std.heap.page_allocator;
    var chart = BarChart.init(allocator, .ascii, 40, false);
    defer chart.deinit();

    try chart.addBar("Apples", 50);
    try chart.addBar("Bananas", 30);
    try chart.addBar("Cherries", 70);
    try chart.addBar("Dates", 20);
    try chart.addBar("Elderberry", 90);
    try chart.printChart();
}

test "unicode bar chart" {
    const allocator = std.heap.page_allocator;
    var chart = BarChart.init(allocator, .unicode, 50, true);
    defer chart.deinit();

    std.debug.print("\n", .{});

    try chart.addBar("CPU", 75);
    try chart.addBar("RAM", 60);
    try chart.addBar("Disk", 90);
    try chart.addBar("Network", 40);
    try chart.printChart();
}

test "sparkline render basic" {
    const data = [_]u64{ 1, 5, 22, 13, 53, 29, 44, 90 };
    const spark = Sparkline(u64).init(&data);

    var buf: [64]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try spark.render(stream.writer());
    try spark.render(std.io.getStdOut().writer());
    const output = stream.getWritten();

    try std.testing.expectEqualStrings("▁▁▂▁▅▃▄█\n", output);
}

test "line chart basic functionality" {
    const allocator = std.heap.page_allocator;
    var chart = LineChart.init(allocator, .ascii, 40, 20);
    defer chart.deinit();

    try chart.addPoint(0, 0, null);
    try chart.addPoint(1, 2, null);
    try chart.addPoint(2, 1, null);
    try chart.addPoint(3, 4, null);
    try chart.addPoint(4, 3, null);

    try testing.expect(chart.points.items.len == 5);
}

test "line chart with simple data" {
    const allocator = std.heap.page_allocator;
    const data = [_]f64{ 1.0, 3.0, 2.0, 5.0, 4.0, 6.0, 5.5, 7.0 };

    var chart = try createSimpleLineChart(allocator, &data, .ascii);
    defer chart.deinit();

    print("\nSimple Line Chart (ASCII):\n", .{});
    try chart.printChart();
    try chart.printStatistics();
}

test "smooth line chart with custom bounds" {
    const allocator = std.heap.page_allocator;
    var chart = LineChart.init(allocator, .smooth, 50, 20);
    defer chart.deinit();

    for (0..20) |i| {
        const x = @as(f64, @floatFromInt(i)) * 0.5;
        const y = @sin(x) * 10.0 + 10.0;
        try chart.addPoint(x, y, null);
    }

    chart.setBounds(0, 10, 0, 20);
    chart = chart.withTitle("Sine Wave")
        .withLabels("Time", "Amplitude")
        .withGrid(true);

    print("\nSmooth Line Chart (Sine Wave):\n", .{});
    try chart.printChart();
}
