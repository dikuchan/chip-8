const std = @import("std");
const sdl = @import("zsdl2");

const Backend = @import("./backend/sdl.zig").Backend;
const Screen = @import("./core/Screen.zig");
const Keypad = @import("./core/Keypad.zig");
const Cli = @import("./cli.zig").Cli;
const Emu = @import("./core/Emu.zig");
const memory = @import("./core/memory.zig");

pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var cli = try Cli.init(allocator);
    defer cli.deinit(allocator);

    std.log.debug("using version {s}", .{@tagName(cli.version)});
    std.log.debug("running at {d} fps", .{cli.fps});
    if (cli.debug) {
        std.log.debug("debug mode is on", .{});
    }

    // TODO: add audio.
    var backend = try Backend.init(
        Emu.SCREEN_WIDTH,
        Emu.SCREEN_HEIGHT,
        10,
    );
    defer backend.deinit();

    var emu = Emu.init(
        try memory.load_file(cli.file),
        .{
            .version = cli.version,
            .debug = cli.debug,
        },
    );
    runLoop(
        &emu,
        backend.screen(),
        backend.keypad(),
    ) catch |err| {
        std.log.err("execution error: {any}", .{err});
    };
}

fn runLoop(emu: *Emu, screen: Screen, keypad: Keypad) !void {
    while (true) {
        while (keypad.poll()) |event| {
            switch (event) {
                .key_down => |key| emu.pressKey(key),
                .key_up => |key| emu.releaseKey(key),
                .skip => continue,
                .quit => return,
            }
        }
        for (0..10) |_| {
            try emu.tick();
        }
        emu.hztick();
        try emu.draw(screen);
    }
}
