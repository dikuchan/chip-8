const sdl = @import("zsdl2");

const Keypad = @import("../Keypad.zig");
const Event = Keypad.Event;
const Key = Keypad.Key;
const Keycode = Keypad.Keycode;
const Keystate = Keypad.Keystate;

fn parseKeycode(keycode: sdl.Keycode) ?Keycode {
    return switch (keycode) {
        .@"1" => Keycode.@"1",
        .@"2" => Keycode.@"2",
        .@"3" => Keycode.@"3",
        .@"4" => Keycode.C,
        .q => Keycode.@"4",
        .w => Keycode.@"5",
        .e => Keycode.@"6",
        .r => Keycode.D,
        .a => Keycode.@"7",
        .s => Keycode.@"8",
        .d => Keycode.@"9",
        .f => Keycode.E,
        .z => Keycode.A,
        .x => Keycode.@"0",
        .c => Keycode.B,
        .v => Keycode.F,
        else => null,
    };
}

pub const Keyboard = struct {
    const Self = @This();

    pub fn poll(_: *anyopaque) ?Event {
        var event: sdl.Event = undefined;
        if (sdl.pollEvent(&event)) {
            switch (event.type) {
                .quit => return Event.quit,
                .keydown => {
                    if (parseKeycode(event.key.keysym.sym)) |keycode| {
                        return .{
                            .key = .{
                                .keycode = keycode,
                                .keystate = Keystate.pressed,
                            },
                        };
                    }
                },
                .keyup => {
                    if (parseKeycode(event.key.keysym.sym)) |keycode| {
                        return .{
                            .key = .{
                                .keycode = keycode,
                                .keystate = Keystate.released,
                            },
                        };
                    }
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
};
