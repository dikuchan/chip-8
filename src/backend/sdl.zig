const sdl = @import("zsdl2");

const Keypad = @import("../core/Keypad.zig");
const Screen = @import("../core/Screen.zig");

const Event = Keypad.Event;
const Key = Keypad.Key;

pub const Backend = struct {
    const Self = @This();

    w: usize,
    h: usize,
    scale: u8,
    window: *sdl.Window,
    renderer: *sdl.Renderer,

    pub fn init(w: usize, h: usize, scale: u8) anyerror!Self {
        try sdl.init(.{
            .audio = true,
            .video = true,
        });
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
        return Self{
            .w = w,
            .h = h,
            .scale = scale,
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn fillBlock(ptr: *anyopaque, x: usize, y: usize, color: Screen.Color) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        switch (color) {
            .black => try self.renderer.setDrawColor(sdl.Color{
                .r = 0x00,
                .g = 0x00,
                .b = 0x00,
                .a = 0x00,
            }),
            .white => try self.renderer.setDrawColor(sdl.Color{
                .r = 0xFF,
                .g = 0xFF,
                .b = 0xFF,
                .a = 0x00,
            }),
        }
        try self.renderer.fillRect(sdl.Rect{
            .x = @intCast(x * self.scale),
            .y = @intCast(y * self.scale),
            .w = self.scale,
            .h = self.scale,
        });
    }

    pub fn render(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.renderer.present();
    }

    pub fn screen(self: *Self) Screen {
        return .{
            .ptr = self,
            .fillBlockFn = fillBlock,
            .renderFn = render,
        };
    }

    pub fn poll(_: *anyopaque) ?Event {
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

    pub fn keypad(self: *Self) Keypad {
        return .{
            .ptr = self,
            .pollFn = poll,
        };
    }

    pub fn deinit(self: *Self) void {
        self.renderer.destroy();
        self.window.destroy();
        sdl.quit();
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
