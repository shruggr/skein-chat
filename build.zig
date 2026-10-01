// skein-workbench (split out of skein by #71): the agent workbench as a skein
// app — the `run` handler (a bash command in the wasm shell over a tree) and
// the chat turn loop (#54), Zig 0.16.0, wasm32-wasi, over the SDK
// (skein-sdk: `cbor`, `sk`, `brc104`). The shell's toolset (brush, coreutils,
// git, jq, python, qjs, …) is built by scripts/build-toolset.sh, not here.
//
//   zig build        → zig-out/bin/run-handler.wasm, zig-out/bin/loop.wasm
//   zig build bin    the same, written to bin/ (the app tree's modules; committed)
//   zig build test   the loop's tests (natively), and both programs built
//
// The builds are reproducible: bin/*.wasm are byte for byte the modules skein
// pins for `run-handler` and `loop` (kernel-zig/src/programs.zig).
const std = @import("std");

const programs = [_]struct { name: []const u8, root: []const u8 }{
    .{ .name = "run-handler", .root = "programs/run-handler/main.zig" },
    .{ .name = "loop", .root = "programs/loop/main.zig" },
};

pub fn build(b: *std.Build) void {
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const bin = b.addUpdateSourceFiles();
    for (programs) |p| {
        const exe = b.addExecutable(.{ .name = p.name, .root_module = module(b, p.root, wasi, .ReleaseSafe, true) });
        b.installArtifact(exe);
        bin.addCopyFileToSource(exe.getEmittedBin(), b.fmt("bin/{s}.wasm", .{p.name}));
    }
    b.step("bin", "write the modules into the app tree: bin/run-handler.wasm, bin/loop.wasm").dependOn(&bin.step);

    const test_step = b.step("test", "the loop's tests, natively; both programs built");
    test_step.dependOn(b.getInstallStep());
    const native = b.standardTargetOptions(.{});
    const gojson = b.addTest(.{ .root_module = module(b, "programs/loop/gojson.zig", native, .Debug, false) });
    test_step.dependOn(&b.addRunArtifact(gojson).step);
}

fn module(b: *std.Build, root: []const u8, t: std.Build.ResolvedTarget, o: std.builtin.OptimizeMode, strip: bool) *std.Build.Module {
    const sdk = b.dependency("skein_sdk", .{ .target = t, .optimize = o, .wallet = false });
    return b.createModule(.{
        .root_source_file = b.path(root),
        .target = t,
        .optimize = o,
        .strip = strip,
        .imports = &.{
            .{ .name = "cbor", .module = sdk.module("cbor") },
            .{ .name = "sk", .module = sdk.module("sk") },
            .{ .name = "brc104", .module = sdk.module("brc104") },
        },
    });
}
