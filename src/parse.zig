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

fn renderRoot(a: *Allocator, ctx: *ItemList, name: []const u8, tree: *Tree) anyerror!void {
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
    if (end_comment > 0) {
        try ctx.append(Item{
            .kind = Item.Kind{ .Package = tree.source[begin_comment..end_comment] },
        });
    }

    var it = tree.root_node.decls.iterator(0);
    while (true) {
        var decl = it.next();
        if (decl == null) {
            break;
        }
        try renderTopLevelDecl(a, ctx, tree, decl.?.*);
    }
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

fn renderTopLevelDecl(a: *Allocator, ctx: *ItemList, tree: *Tree, decl: *Node) anyerror!void {
    switch (decl.id) {
        Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(Node.FnProto, "base", decl);
            if (fn_proto.visib_token != null) {
                const name = tree.tokenSlice(fn_proto.name_token.?);
                var func: Item.FnProto = undefined;
                func.name = name;
                try ctx.append(Item{
                    .kind = Item.Kind{ .FnProto = func },
                });
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

pub fn generate(a: *Allocator, stream: var, name: []const u8, source: []const u8) !void {
    var tree = try parse(a, source);
    defer tree.deinit();
    var ctx = ItemList.init(a);
    defer ctx.deinit();
    try renderRoot(a, &ctx, name, &tree);
    var it = ctx.iterator();
    while (it.next()) |item| {
        try item.print(stream);
    }
}

const ItemList = std.ArrayList(Item);

const Item = struct {
    kind: Kind,

    // Kind defines options for the documentation item. For the high level Api
    // we only have a few options which are.
    const Kind = union(enum) {
        // Package is the toplevel package comment. There is really no concept
        // of packages since each file behaves like a container so this is the
        // toplevel doc comment in a zig file.
        Package: []const u8,

        // FnProto defines documentation for a function.
        FnProto: FnProto,
    };

    const FnProto = struct {
        doc: ?[]const u8,
        name: []const u8,
        params: ?ParamList,

        fn print(self: *const FnProto, stream: var) !void {
            try stream.print("{} (", self.name);
            if (self.params) |*params| {}
            try stream.print(")\n");
            // TODO : print return types
        }
    };

    const BoundInfo = struct {
        name: []const u8,
        name_space: []const u8,
    };

    const Param = struct {
        name: []const u8,
        value: ParamValue,
    };

    const ParamValue = struct {
        pre_symbols: ?StringList,
        value: []const u8,
    };

    const StringList = std.ArrayList([]const u8);
    const ParamList = std.ArrayList(Param);

    fn print(self: *const Item, stream: var) !void {
        switch (self.kind) {
            Kind.Package => |pkg| {
                try stream.print("{}\n", pkg);
            },
            Kind.FnProto => |fn_proto| {
                try fn_proto.print(stream);
            },
            else => {},
        }
    }
};
