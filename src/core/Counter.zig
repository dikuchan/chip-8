//! High resolution counter interface.

const Self = @This();

ptr: *anyopaque,

readFn: *const fn (ptr: *anyopaque) u64,
resetFn: *const fn (ptr: *anyopaque) void,

pub fn read(self: Self) u64 {
    return self.readFn(self.ptr);
}

pub fn reset(self: Self) void {
    self.resetFn(self.ptr);
}
