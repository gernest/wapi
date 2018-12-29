const std = @import("std");
const Buffer = std.Buffer;
const builtin = @import("builtin");
const assert = std.debug.assert;
const warn = std.debug.warn;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ast = std.zig.ast;
const Tree = std.zig.ast.Tree;
const parse = std.zig.parse;
const Token = std.zig.Token;

fn renderRoot(a: *Allocator, stream: var, name: []const u8, tree: *ast.Tree) anyerror!void {
    var tok_it = tree.tokens.iterator(0);
    var begin_comment: usize = 0;
    var begin = true;
    var end_comment: usize = 0;
    while (tok_it.next()) |token| {
        if (token.id != Token.Id.DocComment) break;
        if (begin) {
            begin_comment = token.start;
            begin = false;
        }
        end_comment = token.end;
    }
    try stream.print("@import(\"{}\")\n", name);
    if (end_comment > 0) {
        // file heading comment goes here.
        try stream.print("{}\n", tree.source[begin_comment..end_comment]);
    }

    var it = tree.root_node.decls.iterator(0);
    while (true) {
        var decl = it.next();
        if (decl == null) {
            break;
        }
        try renderTopLevelDecl(a, stream, tree, decl.?.*);
    }
    try stream.print("\n");
}

fn renderTopLevelDecl(a: *Allocator, stream: var, tree: *ast.Tree, decl: *ast.Node) anyerror!void {
    switch (decl.id) {
        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);
        },

        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);
            const name = tree.tokenSlice(var_decl.name_token);
        },

        ast.Node.Id.StructField => {
            const field = @fieldParentPtr(ast.Node.StructField, "base", decl);
        },

        ast.Node.Id.UnionTag => {
            const tag = @fieldParentPtr(ast.Node.UnionTag, "base", decl);
        },

        ast.Node.Id.EnumTag => {
            const tag = @fieldParentPtr(ast.Node.EnumTag, "base", decl);
        },
        else => {},
    }
}

pub fn generate(a: *Allocator, stream: var, name: []const u8, source: []const u8) !void {
    var tree = try parse(a, source);
    defer tree.deinit();
    return renderRoot(a, stream, name, &tree);
}
