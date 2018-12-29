/// wapi is a commandline application that generates api documentation for zig
/// source code.
/// Documentation is generated from doc comments that are found in source files.
/// Zig doc comments are prefixed with `///`
///
/// There is no special syntax needed for comments. The comment text is
/// intepreted as markdown text. Cross referencing of identifiers is not supported yet.
const std = @import("std");
const clap = @import("clap");
const mem = std.mem;
const io = std.io;
const path = std.os.path;
const warn = std.debug.warn;
const Dir = std.os.Dir;
const Entry = std.os.Dir.Entry;
const generate = @import("parse.zig").generate;

fn generateDocs(allocator: *std.mem.Allocator, full_path: []const u8) !void {
    var buf = &try std.Buffer.init(allocator, "");
    defer buf.deinit();
    var stream = io.BufferOutStream.init(buf);
    try walkTree(allocator, &stream.stream, full_path);
    warn("{}\n", buf.toSlice());
}

fn walkTree(allocator: *std.mem.Allocator, stream: var, full_path: []const u8) anyerror!void {
    var dir = try Dir.open(allocator, full_path);
    defer dir.close();
    var full_entry_buf = std.ArrayList(u8).init(allocator);
    defer full_entry_buf.deinit();
    while (try dir.next()) |entry| {
        if (entry.name[0] == '.' or mem.eql(u8, entry.name, "zig-cache")) {
            continue;
        }
        try full_entry_buf.resize(full_path.len + entry.name.len + 1);
        const full_entry_path = full_entry_buf.toSlice();
        mem.copy(u8, full_entry_path, full_path);
        full_entry_path[full_path.len] = path.sep;
        mem.copy(u8, full_entry_path[full_path.len + 1 ..], entry.name);
        switch (entry.kind) {
            Entry.Kind.File => {
                const content = try io.readFileAlloc(allocator, full_entry_path);
                errdefer allocator.free(content);
                try generate(allocator, stream, full_entry_path, content);
                allocator.free(content);
            },
            Entry.Kind.Directory => {
                try walkTree(allocator, stream, full_entry_path);
            },
            else => {},
        }
    }
}

pub fn main() !void {
    const stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    const stdout = &stdout_out_stream.stream;

    var direct_allocator = std.heap.DirectAllocator.init();
    const allocator = &direct_allocator.allocator;
    defer direct_allocator.deinit();

    // First we specify what parameters our program can take.
    const params = comptime []clap.Param([]const u8){clap.Param([]const u8).positional("path")};

    var os_iter = clap.args.OsIterator.init(allocator);
    const iter = &os_iter.iter;
    defer os_iter.deinit();

    var buf = &try std.Buffer.init(allocator, "");
    defer buf.deinit();

    const exe = try iter.next();
    var args = try clap.ComptimeClap([]const u8, params).parse(allocator, clap.args.OsIterator.Error, iter);
    defer args.deinit();
    const pos = args.positionals();
    if (pos.len != 1) {
        warn("missing  path");
        return try clap.help(stdout, params);
    }
    try generateDocs(allocator, pos[0]);
}
