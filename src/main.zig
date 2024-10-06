const std = @import("std");
const sdl = @import("zsdl2");

const Interpr = @import("./interpr.zig");

pub fn main() !void {
    // var interpr = try Interpr.load("./data/logo.ch8");
    // while (true) {
    //     try interpr.tick();
    //     std.time.sleep(250 * std.time.ns_per_ms);
    // }

    try sdl.init(.{
        .audio = true,
        .video = true,
    });
    defer sdl.quit();

    const window = try sdl.Window.create(
        "zig-gamedev-window",
        sdl.Window.pos_undefined,
        sdl.Window.pos_undefined,
        600,
        600,
        .{ .opengl = true, .allow_highdpi = true },
    );
    defer window.destroy();
}
