const sdl = @import("zsdl2");

const Self = @This();

ptr: *anyopaque,

pollFn: *const fn (ptr: *anyopaque) ?Event,

pub fn poll(self: Self) ?Event {
    return self.pollFn(self.ptr);
}

pub const Event = union(enum) {
    key: Key,
    skip,
    quit,
};

pub const Key = struct {
    keycode: Keycode,
    keystate: Keystate,

    pub fn isPressed(key: Key) bool {
        return key.keystate == Keystate.pressed;
    }

    pub fn isReleased(key: Key) bool {
        return key.keystate == Keystate.released;
    }

    pub fn index(key: Key) u4 {
        return @intFromEnum(key.keycode);
    }
};

pub const Keycode = enum {
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
};

pub const Keystate = enum {
    pressed,
    released,
};
