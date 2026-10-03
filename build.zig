// skein-chat (shruggr/skein#83): the chat app — the turn loop (#54) that
// asks an inference peer, keeps each turn, and runs `bash` (in the shell
// app's shell, when the instance has it) and `message` tool calls. Zig
// 0.16.0, wasm32-wasi, over the SDK (skein-sdk: `cbor`, `sk`).
//
//   zig build        → zig-out/bin/loop.wasm
//   zig build bin    the same, written to bin/ (the app tree's module; committed)
//   zig build test   the loop's tests (natively), and the program built
//
// The build is reproducible: bin/loop.wasm is byte for byte what
// `zig build bin` writes from this tree.
const std = @import("std");

const programs = [_]struct { name: []const u8, root: []const u8 }{
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
    b.step("bin", "write the module into the app tree: bin/loop.wasm").dependOn(&bin.step);

    const test_step = b.step("test", "the loop's tests, natively; the program built");
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
        },
    });
}
