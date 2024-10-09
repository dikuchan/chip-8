const Self = @This();

ptr: *anyopaque,

pauseFn: *const fn (ptr: *anyopaque) anyerror!void,
unpauseFn: *const fn (ptr: *anyopaque) anyerror!void,

pub fn pause(self: Self) anyerror!void {
    return self.pauseFn(self.ptr);
}

pub fn unpause(self: Self) anyerror!void {
    return self.unpauseFn(self.ptr);
}
