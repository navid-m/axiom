const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const TreeStyle = enum {
    ascii,
    unicode,
    rounded,
    thick,
};

pub const TreeNode = struct {
    name: []const u8,
    children: ArrayList(*TreeNode),
    allocator: Allocator,
    is_expanded: bool,
    metadata: ?[]const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8) Self {
        return Self{
            .name = name,
            .children = ArrayList(*TreeNode).init(allocator),
            .allocator = allocator,
            .is_expanded = true,
            .metadata = null,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit();
    }

    pub fn addChild(self: *Self, name: []const u8) !*TreeNode {
        const child = try self.allocator.create(TreeNode);
        child.* = TreeNode.init(self.allocator, name);
        try self.children.append(child);
        return child;
    }

    pub fn addChildWithMetadata(self: *Self, name: []const u8, metadata: []const u8) !*TreeNode {
        const child = try self.addChild(name);
        child.metadata = metadata;
        return child;
    }

    pub fn collapse(self: *Self) void {
        self.is_expanded = false;
    }

    pub fn expand(self: *Self) void {
        self.is_expanded = true;
    }

    pub fn toggleExpansion(self: *Self) void {
        self.is_expanded = !self.is_expanded;
    }

    pub fn findChild(self: *Self, name: []const u8) ?*TreeNode {
        for (self.children.items) |child| {
            if (std.mem.eql(u8, child.name, name)) {
                return child;
            }
        }
        return null;
    }

    pub fn getDepth(self: *const Self) usize {
        var max_depth: usize = 0;
        if (self.children.items.len > 0) {
            for (self.children.items) |child| {
                const child_depth = child.getDepth();
                if (child_depth > max_depth) {
                    max_depth = child_depth;
                }
            }
        }
        return max_depth + 1;
    }

    pub fn countNodes(self: *const Self) usize {
        var count: usize = 1;
        for (self.children.items) |child| {
            count += child.countNodes();
        }
        return count;
    }
};

pub const TreeRenderer = struct {
    style: TreeStyle,
    show_metadata: bool,
    show_icons: bool,
    max_depth: ?usize,
    alphabetical_sort: bool,
    color_enabled: bool,

    const Self = @This();

    pub fn init(style: TreeStyle) Self {
        return Self{
            .style = style,
            .show_metadata = false,
            .show_icons = false,
            .max_depth = null,
            .alphabetical_sort = false,
            .color_enabled = false,
        };
    }

    pub fn withMetadata(self: Self, enabled: bool) Self {
        var new_self = self;
        new_self.show_metadata = enabled;
        return new_self;
    }

    pub fn withIcons(self: Self, enabled: bool) Self {
        var new_self = self;
        new_self.show_icons = enabled;
        return new_self;
    }

    pub fn withMaxDepth(self: Self, depth: usize) Self {
        var new_self = self;
        new_self.max_depth = depth;
        return new_self;
    }

    pub fn withAlphabeticalSort(self: Self, enabled: bool) Self {
        var new_self = self;
        new_self.alphabetical_sort = enabled;
        return new_self;
    }

    pub fn withColors(self: Self, enabled: bool) Self {
        var new_self = self;
        new_self.color_enabled = enabled;
        return new_self;
    }

    const TreeChars = struct {
        vertical: []const u8,
        horizontal: []const u8,
        branch: []const u8,
        last_branch: []const u8,
        continuation: []const u8,
        space: []const u8,
    };

    fn getTreeChars(self: *const Self) TreeChars {
        return switch (self.style) {
            .ascii => TreeChars{
                .vertical = "|",
                .horizontal = "-",
                .branch = "|-",
                .last_branch = "`-",
                .continuation = "| ",
                .space = "  ",
            },
            .unicode => TreeChars{
                .vertical = "│",
                .horizontal = "─",
                .branch = "├─",
                .last_branch = "└─",
                .continuation = "│ ",
                .space = "  ",
            },
            .rounded => TreeChars{
                .vertical = "│",
                .horizontal = "─",
                .branch = "├─",
                .last_branch = "╰─",
                .continuation = "│ ",
                .space = "  ",
            },
            .thick => TreeChars{
                .vertical = "┃",
                .horizontal = "━",
                .branch = "┣━",
                .last_branch = "┗━",
                .continuation = "┃ ",
                .space = "  ",
            },
        };
    }

    fn getNodeColor(self: *const Self, node: *const TreeNode) []const u8 {
        if (!self.color_enabled) return "";

        if (node.children.items.len > 0) {
            return "\x1b[1;34m";
        } else {
            return "\x1b[0;37m";
        }
    }

    fn getColorReset(self: *const Self) []const u8 {
        return if (self.color_enabled) "\x1b[0m" else "";
    }

    pub fn render(self: *const Self, writer: anytype, root: *const TreeNode) !void {
        try writer.print("{s}{s}{s}", .{
            self.getNodeColor(root),
            root.name,
            self.getColorReset(),
        });

        if (self.show_metadata and root.metadata != null) {
            try writer.print(" [{s}]", .{root.metadata.?});
        }

        try writer.print("\n", .{});

        if (root.is_expanded and root.children.items.len > 0) {
            try self.renderChildren(writer, root, "", 0);
        }
    }

    fn renderChildren(self: *const Self, writer: anytype, node: *const TreeNode, prefix: []const u8, depth: usize) !void {
        if (self.max_depth != null and depth >= self.max_depth.?) {
            return;
        }

        const chars = self.getTreeChars();

        var children_copy = ArrayList(*TreeNode).init(std.heap.page_allocator);
        defer children_copy.deinit();

        for (node.children.items) |child| {
            try children_copy.append(child);
        }

        if (self.alphabetical_sort) {
            std.sort.block(*TreeNode, children_copy.items, {}, struct {
                fn lessThan(context: void, a: *TreeNode, b: *TreeNode) bool {
                    _ = context;
                    return std.mem.lessThan(u8, a.name, b.name);
                }
            }.lessThan);
        }

        for (children_copy.items, 0..) |child, i| {
            const is_last = i == children_copy.items.len - 1;
            const branch_char = if (is_last) chars.last_branch else chars.branch;
            const continuation_char = if (is_last) chars.space else chars.continuation;

            try writer.print("{s}{s}{s}{s}{s}", .{
                prefix,
                branch_char,
                self.getNodeColor(child),
                child.name,
                self.getColorReset(),
            });

            if (self.show_metadata and child.metadata != null) {
                try writer.print(" [{s}]", .{child.metadata.?});
            }

            try writer.print("\n", .{});

            if (child.is_expanded and child.children.items.len > 0) {
                const new_prefix = try std.fmt.allocPrint(std.heap.page_allocator, "{s}{s}", .{ prefix, continuation_char });
                defer std.heap.page_allocator.free(new_prefix);
                try self.renderChildren(writer, child, new_prefix, depth + 1);
            }
        }
    }

    pub fn renderToString(self: *const Self, allocator: Allocator, root: *const TreeNode) ![]u8 {
        var buffer = ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try self.render(buffer.writer(), root);
        return buffer.toOwnedSlice();
    }

    pub fn printTree(self: *const Self, root: *const TreeNode) !void {
        _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
        try self.render(std.io.getStdOut().writer(), root);
    }

    pub fn printStatistics(_: *const Self, root: *const TreeNode) !void {
        const writer = std.io.getStdOut().writer();
        const total_nodes = root.countNodes();
        const depth = root.getDepth();

        try writer.print("\nTree Statistics:\n", .{});
        try writer.print("  Total nodes: {d}\n", .{total_nodes});
        try writer.print("  Maximum depth: {d}\n", .{depth});
        try writer.print("  Root children: {d}\n", .{root.children.items.len});
    }
};

pub fn createTree(allocator: Allocator, root_name: []const u8) !*TreeNode {
    const root = try allocator.create(TreeNode);
    root.* = TreeNode.init(allocator, root_name);
    return root;
}

test "tree node creation and manipulation" {
    const allocator = std.testing.allocator;
    var root = TreeNode.init(allocator, "root");
    defer root.deinit();

    const child1 = try root.addChild("child1");
    const child2 = try root.addChild("child2");
    _ = try child1.addChild("grandchild1");
    _ = try child2.addChild("grandchild2");

    try std.testing.expect(root.children.items.len == 2);
    try std.testing.expect(child1.children.items.len == 1);
    try std.testing.expect(root.getDepth() == 3);
    try std.testing.expect(root.countNodes() == 5);
}

test "tree rendering ascii" {
    const allocator = std.testing.allocator;
    var root = TreeNode.init(allocator, "Project");
    defer root.deinit();

    const src = try root.addChild("src");
    _ = try src.addChild("main.zig");
    _ = try src.addChild("lib.zig");
    _ = try root.addChild("README.md");

    const renderer = TreeRenderer.init(.ascii);
    const output = try renderer.renderToString(allocator, &root);
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
}

test "tree rendering unicode with metadata" {
    const allocator = std.testing.allocator;
    var root = TreeNode.init(allocator, "Project");
    defer root.deinit();

    const src = try root.addChildWithMetadata("src", "folder");
    _ = try src.addChildWithMetadata("main.zig", "1.2KB");
    _ = try root.addChildWithMetadata("README.md", "856B");

    const renderer = TreeRenderer.init(.unicode).withMetadata(true);
    const output = try renderer.renderToString(allocator, &root);
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "[folder]") != null);
}

test "tree with max depth limit" {
    const allocator = std.testing.allocator;
    var root = TreeNode.init(allocator, "root");
    defer root.deinit();

    const child1 = try root.addChild("child1");
    const grandchild = try child1.addChild("grandchild");
    _ = try grandchild.addChild("great-grandchild");

    const renderer = TreeRenderer.init(.ascii).withMaxDepth(2);
    const output = try renderer.renderToString(allocator, &root);
    defer allocator.free(output);

    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "great-grandchild") == null);
}

test "file system tree example" {
    const allocator = std.testing.allocator;
    const tree = try createTree(allocator, "hi");

    const src = try tree.addChildWithMetadata("src", "directory");
    _ = try src.addChildWithMetadata("main.zig", "1.2KB");
    _ = try src.addChildWithMetadata("lib.zig", "856B");

    const tests = try src.addChildWithMetadata("tests", "directory");
    _ = try tests.addChildWithMetadata("unit_tests.zig", "2.1KB");
    _ = try tests.addChildWithMetadata("integration_tests.zig", "3.4KB");

    const docs = try tree.addChildWithMetadata("docs", "directory");
    _ = try docs.addChildWithMetadata("README.md", "1.8KB");
    _ = try docs.addChildWithMetadata("API.md", "4.2KB");

    _ = try tree.addChildWithMetadata("build.zig", "742B");
    _ = try tree.addChildWithMetadata(".gitignore", "156B");
    defer {
        tree.deinit();
        allocator.destroy(tree);
    }

    const renderer = TreeRenderer.init(.unicode)
        .withMetadata(true)
        .withIcons(true)
        .withColors(true)
        .withAlphabeticalSort(true);

    std.debug.print("\nFile System Tree Example:\n", .{});
    try renderer.printTree(tree);
    try renderer.printStatistics(tree);
}
