const c = @import("./c.zig");
const std = @import("std");

extern fn tree_sitter_zig() ?*c.TSLanguage;

pub fn main() !void {
    try testParser();
}

pub const RenderStyle = union(enum) {
    wip: void,
    spacing: void,
    control: void,
    variable: void,
    uservar: void,
    keyword: void,
    typ: void,
    string: void,
    comment: void,
    docs: void,
};

const Class = struct {
    block: bool = false,
    function_declaration: bool = false,
    source_file: bool = false,
    field_expression: bool = false,
    call_expression: bool = false,
    arguments: bool = false,
    string_literal: bool = false,
    identifier: bool = false,
    field_identifier: bool = false,
    unary_expression: bool = false,
    primitive_type: bool = false,
    unary_operator: bool = false,
    assignment_statement: bool = false,
    assignment_expression: bool = false,
    build_in_call_expr: bool = false,
    visibility_modifier: bool = false,
    parameters: bool = false,
    multiline_string_literal: bool = false,
    line_comment: bool = false,
    anonymous_array_expr: bool = false,
    doc_comment: bool = false,
    @"=": bool = false,
    @";": bool = false,
    @".": bool = false,
    @"(": bool = false,
    @")": bool = false,
    @"{": bool = false,
    @"}": bool = false,
    @"@": bool = false,
    ERROR: bool = false,
    IS_CHAR_0: bool,

    pub fn renderStyle(cs: Class, char: u8) RenderStyle {
        if (char == '\n') return .spacing;
        if (char == '\t') return .spacing;
        if (char == ' ') return .spacing;
        if (cs.line_comment) return .comment;
        if (cs.doc_comment) return .docs;
        if (cs.multiline_string_literal) return .string; // no differentiation between \\ and the text. also, for some reason multiline stuff is really buggy
        if (cs.string_literal) {
            if (cs.IS_CHAR_0) return .control;
            return .string;
        }
        if (cs.@"=") return .control;
        if (cs.@";") return .control;
        if (cs.@".") return .control;
        if (cs.@"(") return .control;
        if (cs.@")") return .control;
        if (cs.@"{") return .control;
        if (cs.@"}") return .control;
        if (cs.@"@") return .control;
        if (cs.unary_operator) return .control;
        if (cs.build_in_call_expr) {
            if (cs.identifier) return .keyword;
            return .control;
        }
        if (cs.primitive_type) return .typ;
        if (cs.identifier) {
            if (cs.field_expression) {
                if (cs.call_expression) return .uservar;
                return .variable;
            }
            return .uservar;
        }
        if (cs.field_identifier) return .variable;
        return .keyword;
    }
    pub fn format(
        classesStruct: Class,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        inline for (@typeInfo(Class).Struct.fields) |field| {
            if (@field(classesStruct, field.name)) {
                try std.fmt.format(out_stream, ".{}", .{field.name});
            }
        }
    }
};

pub const Position = struct { from: u64, to: u64 };
pub const Node = struct {
    node: c.TSNode,
    fn wrap(rawNode: c.TSNode) Node {
        return .{ .node = rawNode };
    }
    pub fn position(n: Node) Position {
        return .{
            .from = c.ts_node_start_byte(n.node),
            .to = c.ts_node_end_byte(n.node),
        };
    }
    fn createClassesStructInternal(n: Node, classesStruct: *Class) void {
        var className = n.class();
        inline for (@typeInfo(Class).Struct.fields) |field| {
            if (field.name[0] == '_') continue;
            if (std.mem.eql(u8, field.name, std.mem.span(className))) {
                @field(classesStruct, field.name) = true;
                break;
            }
        } else if (c.ts_node_is_named(n.node)) {
            std.debug.warn("Unsupported class name: {s}\n", .{className});
        }
        if (n.parent()) |p| p.createClassesStructInternal(classesStruct);
    }
    pub fn createClassesStruct(n: Node, cidx: u64) Class {
        var classes: Class = .{
            .IS_CHAR_0 = @intCast(u32, cidx) == c.ts_node_start_byte(n.node),
        };
        n.createClassesStructInternal(&classes);
        return classes;
    }
    pub fn class(n: Node) []const u8 {
        return std.mem.span(c.ts_node_type(n.node));
    }
    pub fn printClasses(
        n: Node,
        res: *std.ArrayList(u8),
    ) std.mem.Allocator.Error!void {
        if (n.parent()) |up| {
            try up.printClasses(res);
            try res.appendSlice(".");
        }
        try res.appendSlice(n.class());
    }
    pub fn firstChild(n: Node) ?Node {
        const result = c.ts_node_parent(n.node);
        if (c.ts_node_is_null(result)) return null;
        return Node.wrap(result);
    }
    pub fn nextSibling(n: Node) ?Node {
        const result = c.ts_node_parent(n.node);
        if (c.ts_node_is_null(result)) return null;
        return Node.wrap(result);
    }
    pub fn parent(n: Node) ?Node {
        const result = c.ts_node_parent(n.node);
        if (c.ts_node_is_null(result)) return null;
        return Node.wrap(result);
    }
};

pub const TreeCursor = struct {
    cursor: c.TSTreeCursor,
    pub fn init(initialNode: Node) TreeCursor {
        return .{
            .cursor = c.ts_tree_cursor_new(initialNode.node),
        };
    }
    pub fn deinit(tc: *TreeCursor) void {
        c.ts_tree_cursor_delete(&tc.cursor);
    }
    fn goFirstChild(tc: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_first_child(&tc.cursor);
    }
    fn goNextSibling(tc: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_next_sibling(&tc.cursor);
    }
    fn goParent(tc: *TreeCursor) bool {
        return c.ts_tree_cursor_goto_parent(&tc.cursor);
    }
    fn advance(tc: *TreeCursor) bool {
        if (tc.goFirstChild()) return true;
        while (!tc.goNextSibling()) {
            if (!tc.goParent()) return false;
        }
        return true;
    }

    fn node(tc: *TreeCursor) Node {
        return Node.wrap(c.ts_tree_cursor_current_node(&tc.cursor));
    }
    fn fieldName(tc: *TreeCursor) []u8 {
        return c.ts_tree_cursor_current_field_name(&tc.cursor);
    }
    fn fieldID(tc: *TreeCursor) c.TSFieldId {
        return c.ts_tree_cursor_current_field_id(&tc.cursor);
    }
};

pub fn getNodeAtPosition(char: u64, cursor: *TreeCursor) Node {
    var bestMatch: Node = cursor.node();
    while (char < cursor.node().position().from) {
        std.debug.assert(cursor.goParent() == true);
    }
    while (char >= cursor.node().position().from) {
        var currentPosition = cursor.node().position();
        if (char >= currentPosition.from and char < currentPosition.to) {
            bestMatch = cursor.node();
        }
        if (!cursor.advance()) break;
    }
    return bestMatch;
}

pub const RowCol = struct {
    row: u64,
    col: u64,
    fn point(cp: RowCol) c.TSPoint {
        return .{ .row = @intCast(u32, cp.row), .column = @intCast(u32, cp.col) };
    }
    pub fn find(text: []const u8, byte: usize) RowCol {
        var res: RowCol = .{ .row = 0, .col = 0 };
        for (text) |char, i| {
            if (i == byte) break;
            if (char == '\n') {
                res.row = 0;
                res.col += 1;
            } else res.row += 1;
        }
        return res;
    }
};

pub const Tree = struct {
    parser: *c.TSParser,
    tree: *c.TSTree,
    locked: bool,

    pub fn init(sourceCode: []const u8) !Tree {
        var parser = c.ts_parser_new().?;
        errdefer c.ts_parser_delete(parser);
        if (!c.ts_parser_set_language(parser, tree_sitter_zig()))
            return error.IncompatibleLanguageVersion;

        var tree = c.ts_parser_parse_string(parser, null, sourceCode.ptr, @intCast(u32, sourceCode.len)).?;
        errdefer c.ts_tree_delete(tree);

        return Tree{
            .parser = parser,
            .tree = tree,
            .locked = false,
        };
    }
    pub fn deinit(ts: *Tree) void {
        c.ts_tree_delete(ts.tree);
        c.ts_parser_delete(ts.parser);
    }
    pub fn lock(ts: *Tree) void {
        if (ts.locked) unreachable;
        ts.locked = true;
    }
    pub fn unlock(ts: *Tree) void {
        if (!ts.locked) unreachable;
        ts.locked = false;
    }
    pub fn reparse(ts: *Tree, sourceCode: []const u8) void {
        var newTree = c.ts_parser_parse_string(
            ts.parser,
            null,
            sourceCode.ptr,
            @intCast(u32, sourceCode.len),
        ).?;
        c.ts_tree_delete(ts.tree);
        ts.tree = newTree;
    }
    pub fn root(ts: *Tree) Node {
        return Node.wrap(c.ts_tree_root_node(ts.tree));
    }

    pub fn edit(
        ts: *Tree,
        startByte: u64,
        oldEndByte: u64,
        newEndByte: u64,
        start: RowCol,
        oldEnd: RowCol,
        newEnd: RowCol,
    ) void {
        if (ts.locked) unreachable;
        c.ts_tree_edit(ts.tree, &c.TSInputEdit{
            .start_byte = @intCast(u32, startByte),
            .old_end_byte = @intCast(u32, oldEndByte),
            .new_end_byte = @intCast(u32, newEndByte),
            .start_point = start.point(),
            .old_end_point = oldEnd.point(),
            .new_end_point = newEnd.point(),
        });
    }
};
