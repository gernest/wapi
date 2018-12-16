const build_pkg = @import("std").build;
const Builder = build_pkg.Builder;

const Pkg = struct {
    name: []const u8,
    path: []const u8,
};

const packages = struct {
    const list = []Pkg{Pkg{ .name = "clap", .path = "lib/clap/src/index.zig" }};
    fn addTo(ts: var) void {
        for (list) |p| {
            ts.addPackagePath(p.name, p.path);
        }
    }
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("wapi", "src/main.zig");
    packages.addTo(exe);
    exe.setBuildMode(mode);
    var main_tests = b.addTest("src/main.zig");
    packages.addTo(main_tests);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run app tests");
    test_step.dependOn(&main_tests.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
