const std = @import("std");
const sdl = @import("zsdl2");

const Emulator = @import("./Emulator.zig");
const memory = @import("./memory.zig");
const Video = @import("./driver/Video.zig");

pub fn main() !void {
    try sdl.init(.{
        .audio = true,
        .video = true,
    });
    defer sdl.quit();

    var video = try Video.init();
    defer video.deinit();
    var emulator = Emulator.init(
        try memory.load_file("./data/logo.ch8"),
        &video,
    );

    loop: while (true) {
        var event: sdl.Event = undefined;
        while (sdl.pollEvent(&event)) {
            if (event.type == .quit) {
                break :loop;
            }
        }
        try emulator.tick();
        sdl.delay(17);
    }
}
