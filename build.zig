const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "chip-8",
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
    });

    const zsdl = b.dependency("zsdl", .{});
    exe.root_module.addImport("zsdl2", zsdl.module("zsdl2"));

    @import("zsdl").prebuilt.addLibraryPathsTo(exe);

    if (@import("zsdl").prebuilt.install_SDL2(b, target.result, .bin)) |install_sdl2_step| {
        b.getInstallStep().dependOn(install_sdl2_step);
    }

    @import("zsdl").link_SDL2(exe);

    b.installArtifact(exe);
}
