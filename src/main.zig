const std = @import("std");
const ast = std.zig.ast;
pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n");
}

test "all" {
    _ = @import("parse.zig");
}
