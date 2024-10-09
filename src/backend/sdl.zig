const std = @import("std");
const sdl = @import("zsdl2");

const Counter = @import("../core/Counter.zig");
const Keypad = @import("../core/Keypad.zig");
const Screen = @import("../core/Screen.zig");

const Event = Keypad.Event;
const Key = Keypad.Key;

const CounterBackend = struct {
    started: u64,

    fn init() CounterBackend {
        return .{ .started = 0 };
    }

    fn read(ptr: *anyopaque) u64 {
        const self: *CounterBackend = @ptrCast(@alignCast(ptr));
        return (sdl.getPerformanceCounter() - self.started) * std.time.ns_per_s / sdl.getPerformanceFrequency();
    }

    fn reset(ptr: *anyopaque) void {
        const self: *CounterBackend = @ptrCast(@alignCast(ptr));
        self.started = sdl.getPerformanceCounter();
    }
};

const KeypadBackend = struct {
    fn init() KeypadBackend {
        return .{};
    }

    fn poll(_: *anyopaque) ?Event {
        var event: sdl.Event = undefined;
        if (sdl.pollEvent(&event)) {
            switch (event.type) {
                .quit => return Event.quit,
                .keydown => {
                    if (keycodeToKey(event.key.keysym.sym)) |key| {
                        return .{ .key_down = key };
                    }
                    return Event.skip;
                },
                .keyup => {
                    if (keycodeToKey(event.key.keysym.sym)) |key| {
                        return .{ .key_up = key };
                    }
                    return Event.skip;
                },
                else => return Event.skip,
            }
        }
        return null;
    }
};

fn keycodeToKey(keycode: sdl.Keycode) ?Key {
    return switch (keycode) {
        .@"1" => Key.@"1",
        .@"2" => Key.@"2",
        .@"3" => Key.@"3",
        .@"4" => Key.C,
        .q => Key.@"4",
        .w => Key.@"5",
        .e => Key.@"6",
        .r => Key.D,
        .a => Key.@"7",
        .s => Key.@"8",
        .d => Key.@"9",
        .f => Key.E,
        .z => Key.A,
        .x => Key.@"0",
        .c => Key.B,
        .v => Key.F,
        else => null,
    };
}

const ScreenBackend = struct {
    w: usize,
    h: usize,
    scale: u8,
    window: *sdl.Window,
    renderer: *sdl.Renderer,

    fn init(w: usize, h: usize, scale: u8) !ScreenBackend {
        const window = try sdl.Window.create(
            "CHIP-8",
            sdl.Window.pos_undefined,
            sdl.Window.pos_undefined,
            @intCast(w * scale),
            @intCast(h * scale),
            .{ .opengl = true },
        );
        const renderer = try sdl.createRenderer(
            window,
            -1,
            .{ .accelerated = true, .present_vsync = true },
        );
        return .{
            .w = w,
            .h = h,
            .scale = scale,
            .window = window,
            .renderer = renderer,
        };
    }

    fn clear(ptr: *anyopaque) anyerror!void {
        const self: *ScreenBackend = @ptrCast(@alignCast(ptr));
        try self.renderer.setDrawColor(BLACK_COLOR);
        try self.renderer.clear();
    }

    fn fillBlock(ptr: *anyopaque, x: usize, y: usize, color: Screen.Color) anyerror!void {
        const self: *ScreenBackend = @ptrCast(@alignCast(ptr));
        switch (color) {
            .black => try self.renderer.setDrawColor(BLACK_COLOR),
            .white => try self.renderer.setDrawColor(WHITE_COLOR),
        }
        try self.renderer.fillRect(sdl.Rect{
            .x = @intCast(x * self.scale),
            .y = @intCast(y * self.scale),
            .w = self.scale,
            .h = self.scale,
        });
    }

    fn render(ptr: *anyopaque) anyerror!void {
        const self: *ScreenBackend = @ptrCast(@alignCast(ptr));
        self.renderer.present();
    }

    fn deinit(self: ScreenBackend) void {
        self.renderer.destroy();
        self.window.destroy();
    }
};

const BLACK_COLOR = sdl.Color{
    .r = 0x00,
    .g = 0x00,
    .b = 0x00,
    .a = 0x00,
};
const WHITE_COLOR = sdl.Color{
    .r = 0xFF,
    .g = 0xFF,
    .b = 0xFF,
    .a = 0x00,
};

pub const Backend = struct {
    const Self = @This();

    counter_backend: CounterBackend,
    keypad_backend: KeypadBackend,
    screen_backend: ScreenBackend,

    pub fn init(w: usize, h: usize, scale: u8) anyerror!Self {
        try sdl.init(.{
            .audio = true,
            .video = true,
        });
        return Self{
            .counter_backend = CounterBackend.init(),
            .keypad_backend = KeypadBackend.init(),
            .screen_backend = try ScreenBackend.init(w, h, scale),
        };
    }

    pub fn counter(self: *Backend) Counter {
        return .{
            .ptr = &self.counter_backend,
            .readFn = CounterBackend.read,
            .resetFn = CounterBackend.reset,
        };
    }

    pub fn keypad(self: *Backend) Keypad {
        return .{
            .ptr = &self.keypad_backend,
            .pollFn = KeypadBackend.poll,
        };
    }

    pub fn screen(self: *Backend) Screen {
        return .{
            .ptr = &self.screen_backend,
            .clearFn = ScreenBackend.clear,
            .fillBlockFn = ScreenBackend.fillBlock,
            .renderFn = ScreenBackend.render,
        };
    }

    pub fn deinit(self: *Self) void {
        self.screen.deinit();
        sdl.quit();
    }
};
