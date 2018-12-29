const std = @import("std");
const io = std.io;
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
const Node = ast.Node;
const PrefixOp = Node.PrefixOp;

fn renderRoot(a: *Allocator, stream: var, name: []const u8, tree: *Tree) anyerror!void {
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
        try printComments(a, stream, tree.source[begin_comment..end_comment]);
        try stream.print("\n");
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

fn removePrefix(s: []const u8, prefix: []const u8) []const u8 {
    if (s.len < prefix.len) {
        return s;
    }
    if (!mem.eql(u8, s[0..prefix.len], prefix)) {
        return s;
    }
    return s[prefix.len..];
}

/// printComments prints comments to the stream. comments is a slice of zig doc comments.
/// The printed string will be without the prefixed /// characters.
///
/// Any errors such as OutOfMemory will be returned. This will do nothing if
/// comments is empty.
fn printComments(a: *Allocator, stream: var, comments: []const u8) !void {
    var comment_stream = std.io.SliceInStream.init(comments);
    var buf = try Buffer.init(a, "");
    defer buf.deinit();
    while (true) {
        if (io.readLineFrom(&comment_stream.stream, &buf)) |comment| {
            try stream.print("{}\n", removePrefix(comment, "///"));
        } else |err| {
            if (err != error.EndOfStream) {
                return err;
            }
            break;
        }
    }
}

fn renderTopLevelDecl(a: *Allocator, stream: var, tree: *Tree, decl: *Node) anyerror!void {
    switch (decl.id) {
        Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(Node.FnProto, "base", decl);
            if (fn_proto.visib_token != null) {
                const name = tree.tokenSlice(fn_proto.name_token.?);
                try stream.print("pub fn {} (", name);
                var it = &fn_proto.params.iterator(0);
                var start = true;
                while (true) {
                    var param_ptr = it.next();
                    if (param_ptr == null) {
                        break;
                    }
                    var param = param_ptr.?.*;
                    if (!start) {
                        try stream.print(", ");
                    } else {
                        start = false;
                    }
                    var param_decl = @fieldParentPtr(Node.ParamDecl, "base", param);
                    try renderParam(a, stream, param_decl, tree);
                }
                try stream.print(")");
            }
        },

        Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(Node.VarDecl, "base", decl);
            const name = tree.tokenSlice(var_decl.name_token);
        },

        Node.Id.StructField => {
            const field = @fieldParentPtr(Node.StructField, "base", decl);
        },

        Node.Id.UnionTag => {
            const tag = @fieldParentPtr(Node.UnionTag, "base", decl);
        },

        Node.Id.EnumTag => {
            const tag = @fieldParentPtr(Node.EnumTag, "base", decl);
        },
        else => {},
    }
}

fn renderParam(a: *Allocator, stream: var, decl: *Node.ParamDecl, tree: *Tree) !void {
    if (decl.comptime_token != null) {
        try stream.print("comptime ");
    }
    const name = tree.tokenSlice(decl.name_token.?);
    try stream.print("{}: ", name);
    switch (decl.type_node.id) {
        Node.Id.VarType => {
            try stream.print("{}", decl.type_node.id);
            // try stream.print("var");
        },
        Node.Id.PrefixOp => {
            var ops_type = @fieldParentPtr(Node.PrefixOp, "base", decl.type_node);
            switch (ops_type.op) {
                PrefixOp.Op.PtrType => |info| {
                    switch (ops_type.rhs.id) {
                        Node.Id.Identifier => {
                            var ident = @fieldParentPtr(Node.Identifier, "base", decl.type_node);
                            const ident_name = tree.tokenSlice(ident.token);
                            const next = tree.tokenSlice(ident.token + 1);
                            try stream.print("{}{}", ident_name, next);
                        },
                        else => {},
                    }
                },
                else => {},
            }
        },
        else => {
            try stream.print("{}", decl.type_node.id);
        },
    }
}

pub fn generate(a: *Allocator, stream: var, name: []const u8, source: []const u8) !void {
    var tree = try parse(a, source);
    defer tree.deinit();
    return renderRoot(a, stream, name, &tree);
}
