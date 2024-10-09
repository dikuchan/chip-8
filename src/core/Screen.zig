//! Screen interface.

const Self = @This();

pub const Color = enum {
    black,
    white,
};

ptr: *anyopaque,

clearFn: *const fn (ptr: *anyopaque) anyerror!void,
fillBlockFn: *const fn (ptr: *anyopaque, x: usize, y: usize, color: Color) anyerror!void,
showOpcodeFn: *const fn (ptr: *anyopaque, opcode: u16) anyerror!void,
renderFn: *const fn (ptr: *anyopaque) anyerror!void,

pub fn clear(self: Self) anyerror!void {
    return self.clearFn(self.ptr);
}

pub fn fillBlock(self: Self, x: usize, y: usize, color: Color) anyerror!void {
    return self.fillBlockFn(self.ptr, x, y, color);
}

pub fn showOpcode(self: Self, opcode: u16) anyerror!void {
    return self.showOpcodeFn(self.ptr, opcode);
}

pub fn render(self: Self) anyerror!void {
    return self.renderFn(self.ptr);
}
