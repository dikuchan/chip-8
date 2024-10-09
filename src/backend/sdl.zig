const std = @import("std");
const sdl = @import("zsdl2");
const sdl_ttf = @import("zsdl2_ttf");

const Counter = @import("../core/Counter.zig");
const Keypad = @import("../core/Keypad.zig");
const Screen = @import("../core/Screen.zig");
const Sound = @import("../core/Sound.zig");

const Event = Keypad.Event;
const Key = Keypad.Key;

const FONT_PATH = "./data/fonts/Ubuntu-Regular.ttf";
const FONT_SIZE = 24;
const OPCODE_TEXT_LENGTH = 4;

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
                    if (event.key.keysym.sym == .space) {
                        return .debug;
                    }
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
    font: *sdl_ttf.Font,

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
        const font = try sdl_ttf.Font.open(FONT_PATH, FONT_SIZE);
        return .{
            .w = w,
            .h = h,
            .scale = scale,
            .window = window,
            .renderer = renderer,
            .font = font,
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

    pub fn showOpcode(ptr: *anyopaque, opcode: u16) anyerror!void {
        const self: *ScreenBackend = @ptrCast(@alignCast(ptr));

        var opcodeBuffer: [OPCODE_TEXT_LENGTH]u8 = undefined;
        const opcodeString = try std.fmt.bufPrint(&opcodeBuffer, "{X:0>4}", .{opcode});
        var text: [OPCODE_TEXT_LENGTH:0]u8 = undefined;
        text[OPCODE_TEXT_LENGTH] = 0;
        @memcpy(&text, opcodeString);

        const surface = try self.font.renderTextShaded(&text, GREEN_COLOR, BLACK_COLOR);
        defer surface.free();
        const texture = try self.renderer.createTextureFromSurface(surface);
        defer texture.destroy();
        try sdl.renderCopy(self.renderer, texture, null, &sdl.Rect{
            .x = 0,
            .y = 0,
            .w = surface.w,
            .h = surface.h,
        });
    }

    fn render(ptr: *anyopaque) anyerror!void {
        const self: *ScreenBackend = @ptrCast(@alignCast(ptr));
        self.renderer.present();
    }

    fn deinit(self: ScreenBackend) void {
        self.font.close();
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
const GREEN_COLOR = sdl.Color{
    .r = 0x00,
    .g = 0x80,
    .b = 0x00,
    .a = 0x00,
};

const SoundBackend = struct {
    device_id: u32,

    fn init() SoundBackend {
        const desired_audio_spec = sdl.AudioSpec{
            .format = sdl.AUDIO_U16,
            .freq = 44100,
            .channels = 1,
            .samples = 128,
            .callback = fillAudio,
        };
        var obtained_audio_spec: sdl.AudioSpec = undefined;
        const audio_device_id = sdl.openAudioDevice(
            null,
            false,
            &desired_audio_spec,
            &obtained_audio_spec,
            0,
        );
        return .{
            .device_id = audio_device_id,
        };
    }

    // TODO: define sound.
    fn fillAudio(_: ?*anyopaque, _: [*c]u8, _: c_int) callconv(.C) void {
        return;
    }

    fn pause(ptr: *anyopaque) !void {
        const self: *SoundBackend = @ptrCast(@alignCast(ptr));
        sdl.pauseAudioDevice(self.device_id, true);
    }

    fn unpause(ptr: *anyopaque) !void {
        const self: *SoundBackend = @ptrCast(@alignCast(ptr));
        sdl.pauseAudioDevice(self.device_id, false);
    }

    fn deinit(self: SoundBackend) void {
        sdl.clearQueuedAudio(self.device_id);
    }
};

pub const Backend = struct {
    const Self = @This();

    counter_backend: CounterBackend,
    keypad_backend: KeypadBackend,
    screen_backend: ScreenBackend,
    sound_backend: SoundBackend,

    pub fn init(w: usize, h: usize, scale: u8) anyerror!Self {
        try sdl.init(.{
            .audio = true,
            .video = true,
        });
        try sdl_ttf.init();
        return Self{
            .counter_backend = CounterBackend.init(),
            .keypad_backend = KeypadBackend.init(),
            .screen_backend = try ScreenBackend.init(w, h, scale),
            .sound_backend = SoundBackend.init(),
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
            .showOpcodeFn = ScreenBackend.showOpcode,
            .renderFn = ScreenBackend.render,
        };
    }

    pub fn sound(self: *Backend) Sound {
        return .{
            .ptr = &self.sound_backend,
            .pauseFn = SoundBackend.pause,
            .unpauseFn = SoundBackend.unpause,
        };
    }

    pub fn deinit(self: *Self) void {
        self.sound_backend.deinit();
        self.screen_backend.deinit();
        sdl_ttf.quit();
        sdl.quit();
    }
};
