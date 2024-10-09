const std = @import("std");
const sdl = @import("zsdl2");

const Cli = @import("./cli.zig").Cli;

const Counter = @import("./core/Counter.zig");
const Emulator = @import("./core/Emulator.zig");
const Keypad = @import("./core/Keypad.zig");
const memory = @import("./core/memory.zig");
const Screen = @import("./core/Screen.zig");

const Backend = @import("./backend/sdl.zig").Backend;

const FRAME_PER_S = 60;
const NS_PER_FRAME = std.time.ns_per_s / FRAME_PER_S;
const TICK_PER_FRAME = 10;

pub fn main() !void {
    var buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var cli = try Cli.init(allocator);
    defer cli.deinit(allocator);

    std.log.debug("using version: {s}", .{@tagName(cli.version)});
    if (cli.debug) {
        std.log.debug("debug mode is on", .{});
    }

    // TODO: add audio.
    var backend = try Backend.init(
        Emulator.SCREEN_WIDTH,
        Emulator.SCREEN_HEIGHT,
        10,
    );
    defer backend.deinit();

    var e = Emulator.init(
        try memory.load_file(cli.file),
        .{
            .version = cli.version,
            .debug = cli.debug,
        },
    );
    runLoop(
        &e,
        backend.counter(),
        backend.keypad(),
        backend.screen(),
    ) catch |err| {
        std.log.err("execution error: {any}", .{err});
    };
}

fn runLoop(e: *Emulator, counter: Counter, keypad: Keypad, screen: Screen) !void {
    while (true) {
        counter.reset();
        try screen.clear();

        while (keypad.poll()) |event| {
            switch (event) {
                .key_down => |key| e.pressKey(key),
                .key_up => |key| e.releaseKey(key),
                .skip => continue,
                .quit => return,
            }
        }

        for (0..TICK_PER_FRAME) |_| {
            try e.tick();
        }
        e.frameTick();

        try e.draw(screen);
        try screen.render();

        const elapsed = counter.read();
        if (elapsed < NS_PER_FRAME) {
            std.time.sleep(NS_PER_FRAME - elapsed);
        }
    }
}
