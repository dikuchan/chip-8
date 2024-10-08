const sdl = @import("zsdl2");

pub const WIDTH = 64;
pub const HEIGHT = 32;

const SCALE = 20;

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

const Self = @This();

screen: [WIDTH][HEIGHT]u1,
window: *sdl.Window,
renderer: *sdl.Renderer,
should_render: bool,

pub fn init() !Self {
    const window = try sdl.Window.create(
        "CHIP-8",
        sdl.Window.pos_undefined,
        sdl.Window.pos_undefined,
        WIDTH * SCALE,
        HEIGHT * SCALE,
        .{ .opengl = true },
    );
    const renderer = try sdl.createRenderer(
        window,
        -1,
        .{ .accelerated = true },
    );
    var screen: [WIDTH][HEIGHT]u1 = undefined;
    for (0..WIDTH) |i| {
        screen[i] = [_]u1{0} ** HEIGHT;
    }
    var video = Self{
        .screen = screen,
        .window = window,
        .renderer = renderer,
        .should_render = false,
    };
    try video.render();
    return video;
}

pub fn clear_screen(self: *Self) void {
    for (0..WIDTH) |x| {
        for (0..HEIGHT) |y| {
            self.screen[x][y] = 0;
        }
    }
    self.should_render = true;
}

pub fn set_pixel(self: *Self, x: usize, y: usize, value: u1) void {
    self.screen[x][y] = value;
    self.should_render = true;
}

pub fn get_pixel(self: *Self, x: usize, y: usize) u1 {
    return self.screen[x][y];
}

pub fn render(self: *Self) !void {
    if (!self.should_render) {
        return;
    }
    for (0..WIDTH) |x| {
        for (0..HEIGHT) |y| {
            if (self.screen[x][y] == 0) {
                try self.renderer.setDrawColor(BLACK_COLOR);
            } else {
                try self.renderer.setDrawColor(WHITE_COLOR);
            }
            try self.renderer.fillRect(sdl.Rect{
                .x = @intCast(x * SCALE),
                .y = @intCast(y * SCALE),
                .w = SCALE,
                .h = SCALE,
            });
        }
    }
    self.renderer.present();
    self.should_render = false;
}

pub fn deinit(self: *Self) void {
    self.renderer.destroy();
    self.window.destroy();
}
