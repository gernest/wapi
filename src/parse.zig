const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const warn = std.debug.warn;
const mem = std.mem;
const Allocator = mem.Allocator;
const ast = std.zig.ast;
const parse = std.zig.parse;
const Token = std.zig.Token;

const Package = struct {
    name: []const u8,
    doc: ?[]const u8,

    fn init(name: []const u8) Package {
        return Package{ .doc = null, .name = name };
    }
};

const ObjectList = std.ArrayList(*Object);

// Object describes a documented object. We only document public API which is
// evaluated from top down. This means a if a parent is private, all it will be
// ignored together with its members even if some/all of its members are public..
//
const Object = struct {
    path: []const u8,
    doc: ?[]const u8,
    args: ?ObjectList,
    location: ast.Location,

    const Encoding = struct {
        const Enum = 'E';
        const Field = 'E';
        const Func = 'C';
        const Method = 'M';
        const Struct = 'S';
    };
};

fn renderRoot(allocator: *mem.Allocator, name: []const u8, tree: *ast.Tree) anyerror!Package {
    var tok_it = tree.tokens.iterator(0);
    var pkg = Package.init(name);

    // first consucutive doc comments at the beginning of the file are marked as
    // package level documentation.
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
    if (end_comment > 0) {
        pkg.doc = tree.source[begin_comment..end_comment];
    }
    var it = tree.root_node.decls.iterator(0);
    while (true) {
        var decl = it.next();
        if (decl == null) {
            break;
        }
        try renderTopLevelDecl(allocator, tree, decl.?.*);
    }
    return pkg;
}

test "root" {
    const src =
        \\ ///this is a comment
        \\ ///spanning  many lines
        \\ var a:=12;
    ;
    var a = std.debug.global_allocator;
    var tree = try parse(a, src);
    defer tree.deinit();
    const pkg = try renderRoot(a, "test.zig", &tree);
    warn("{}\n", pkg);
}

fn renderTopLevelDecl(allocator: *mem.Allocator, tree: *ast.Tree, decl: *ast.Node) anyerror!void {
    switch (decl.id) {
        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);
        },

        ast.Node.Id.Use => {
            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);
        },

        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);
            const name = tree.tokenSlice(var_decl.name_token);
            warn("name :{}\n", name);
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
