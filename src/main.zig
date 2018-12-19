const std = @import("std");
const ast = std.zig.ast;

pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n");
}

const Package = struct {
    doc: ?[]const u8,
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
