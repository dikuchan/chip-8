const std = @import("std");
const sdl = @import("zsdl2");

const Self = @This();

pub const Keypad = [16]bool;

pub const KeypadError = error{
    Quit,
};

pub fn poll() !Keypad {
    var event: sdl.Event = undefined;
    while (sdl.pollEvent(&event)) {
        if (event.type == .quit) {
            return KeypadError.Quit;
        }
    }

    var keypad = [_]bool{false} ** 16;
    const keystate = sdl.getKeyboardState();
    for ([_]sdl.Scancode{
        sdl.Scancode.@"1",
        sdl.Scancode.@"2",
        sdl.Scancode.@"3",
        sdl.Scancode.@"4",
        sdl.Scancode.q,
        sdl.Scancode.w,
        sdl.Scancode.e,
        sdl.Scancode.r,
        sdl.Scancode.a,
        sdl.Scancode.s,
        sdl.Scancode.d,
        sdl.Scancode.f,
        sdl.Scancode.z,
        sdl.Scancode.x,
        sdl.Scancode.c,
        sdl.Scancode.v,
    }, [_]u4{
        0x1,
        0x2,
        0x3,
        0xC,
        0x4,
        0x5,
        0x6,
        0xD,
        0x7,
        0x8,
        0x9,
        0xE,
        0xA,
        0x0,
        0xB,
        0xF,
    }) |scancode, i| {
        if (isKeyPressed(keystate, scancode)) {
            keypad[i] = true;
        }
    }

    return keypad;
}

fn isKeyPressed(keystate: []const u8, scancode: sdl.Scancode) bool {
    return keystate[@intFromEnum(scancode)] > 0;
}
