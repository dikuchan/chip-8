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
    exe.root_module.addImport("zsdl2_ttf", zsdl.module("zsdl2_ttf"));

    @import("zsdl").prebuilt.addLibraryPathsTo(exe);

    if (@import("zsdl").prebuilt.install_SDL2(b, target.result, .bin)) |install_sdl2_step| {
        b.getInstallStep().dependOn(install_sdl2_step);
    }
    if (@import("zsdl").prebuilt.install_SDL2_ttf(b, target.result, .bin)) |install_sdl2_ttf_step| {
        exe.step.dependOn(install_sdl2_ttf_step);
    }

    @import("zsdl").link_SDL2(exe);
    @import("zsdl").link_SDL2_ttf(exe);

    b.installArtifact(exe);
}
