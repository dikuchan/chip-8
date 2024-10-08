const std = @import("std");
const sdl = @import("zsdl2");

const Cli = @import("./cli.zig").Cli;
const Emulator = @import("./Emulator.zig");
const memory = @import("./memory.zig");
const Version = @import("./version.zig").Version;
const Video = @import("./driver/Video.zig");

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

    var video = try Video.init();
    defer video.deinit();

    std.log.debug("using version {s}", .{cli.version.toString()});
    if (cli.debug) {
        std.log.debug("debug mode is on", .{});
    }

    var emulator = Emulator.init(
        try memory.load_file(cli.file),
        video,
        .{
            .version = cli.version,
            .debug = cli.debug,
        },
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
