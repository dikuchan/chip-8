//! Keypad interface.

const Self = @This();

ptr: *anyopaque,

pollFn: *const fn (ptr: *anyopaque) ?Event,

pub fn poll(self: Self) ?Event {
    return self.pollFn(self.ptr);
}

pub const Event = union(enum) {
    debug,
    key_down: Key,
    key_up: Key,
    skip,
    quit,
};

pub const Key = enum {
    @"1",
    @"2",
    @"3",
    C,
    @"4",
    @"5",
    @"6",
    D,
    @"7",
    @"8",
    @"9",
    E,
    A,
    @"0",
    B,
    F,

    pub fn index(key: Key) u4 {
        return @intFromEnum(key);
    }
};
