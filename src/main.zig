const std = @import("std");
const sdl = @import("zsdl2");

const Cli = @import("./cli.zig").Cli;
const Emulator = @import("./Emulator.zig");
const memory = @import("./memory.zig");
const Version = @import("./version.zig").Version;

const Keyboard = @import("./backend/sdl/keyboard.zig").Keyboard;
const Video = @import("./backend/sdl/video.zig").Video;

pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var cli = try Cli.init(allocator);
    defer cli.deinit(allocator);

    try sdl.init(.{
        .audio = true,
        .video = true,
    });
    defer sdl.quit();

    var video = try Video.init(
        Emulator.SCREEN_WIDTH,
        Emulator.SCREEN_HEIGHT,
        10,
    );
    defer video.deinit();

    std.log.debug("using version {s}", .{cli.version.toString()});
    std.log.debug("running at {d} fps", .{cli.fps});
    if (cli.debug) {
        std.log.debug("debug mode is on", .{});
    }

    var emulator = Emulator.init(
        try memory.load_file(cli.file),
        .{
            .version = cli.version,
            .debug = cli.debug,
        },
    );

    var keyboard = Keyboard{};
    var keypad = keyboard.keypad();

    loop: while (true) {
        while (keypad.poll()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.isPressed()) {
                        emulator.press_key(key.index());
                    } else if (key.isReleased()) {
                        emulator.release_key(key.index());
                    }
                },
                .skip => continue,
                .quit => break :loop,
            }
        }
        for (0..10) |_| {
            try emulator.tick();
        }
        emulator.tick_timers();
        try emulator.display(video.renderer());
    }
}
