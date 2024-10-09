const Self = @This();

pub const Color = enum {
    black,
    white,
};

ptr: *anyopaque,

fillBlockFn: *const fn (ptr: *anyopaque, x: usize, y: usize, color: Color) anyerror!void,
renderFn: *const fn (ptr: *anyopaque) anyerror!void,

pub fn fillBlock(self: Self, x: usize, y: usize, color: Color) anyerror!void {
    return self.fillBlockFn(self.ptr, x, y, color);
}

pub fn render(self: Self) anyerror!void {
    return self.renderFn(self.ptr);
}
