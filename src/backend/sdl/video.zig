const sdl = @import("zsdl2");

const Renderer = @import("../Renderer.zig");

pub const Video = struct {
    const Self = @This();

    w: usize,
    h: usize,
    scale: u8,
    window: *sdl.Window,
    rndr: *sdl.Renderer,

    pub fn init(
        w: usize,
        h: usize,
        scale: u8,
    ) anyerror!Self {
        const window = try sdl.Window.create(
            "CHIP-8",
            sdl.Window.pos_undefined,
            sdl.Window.pos_undefined,
            @intCast(w * scale),
            @intCast(h * scale),
            .{ .opengl = true },
        );
        const rndr = try sdl.createRenderer(
            window,
            -1,
            .{ .accelerated = true, .present_vsync = true },
        );
        return Self{
            .w = w,
            .h = h,
            .scale = scale,
            .window = window,
            .rndr = rndr,
        };
    }

    pub fn fillBlock(ptr: *anyopaque, x: usize, y: usize, color: Renderer.Color) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        switch (color) {
            .black => try self.rndr.setDrawColor(sdl.Color{
                .r = 0x00,
                .g = 0x00,
                .b = 0x00,
                .a = 0x00,
            }),
            .white => try self.rndr.setDrawColor(sdl.Color{
                .r = 0xFF,
                .g = 0xFF,
                .b = 0xFF,
                .a = 0x00,
            }),
        }
        try self.rndr.fillRect(sdl.Rect{
            .x = @intCast(x * self.scale),
            .y = @intCast(y * self.scale),
            .w = self.scale,
            .h = self.scale,
        });
    }

    pub fn render(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.rndr.present();
    }

    pub fn renderer(self: *Self) Renderer {
        return .{
            .ptr = self,
            .fillBlockFn = fillBlock,
            .renderFn = render,
        };
    }

    pub fn deinit(self: *Self) void {
        self.rndr.destroy();
        self.window.destroy();
    }
};
