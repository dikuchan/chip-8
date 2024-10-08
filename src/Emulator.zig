const std = @import("std");
const rand = std.crypto.random;

const Keypad = @import("./driver/keypad.zig").Keypad;
const Memory = @import("./memory.zig").Memory;
const Stack = @import("./stack.zig").Stack;
const Version = @import("./version.zig").Version;
const Video = @import("./driver/Video.zig");

const logger = std.log.scoped(.emulator);

pub const EmulatorError = error{
    InvalidInstruction,
    UnsupportedInstruction,
    StackOverflow,
    StackUnderflow,
    RenderingFailed,
};

const Self = @This();

pc: u16,
ir: u16,
vr: [16]u8,
stack: Stack(16),
memory: Memory,

// Drivers.
video: Video,

// Timers.
delay_timer: u8,
sound_timer: u8,

// Meta.
version: Version,
debug: bool,

const Config = struct {
    version: Version,
    debug: bool,
};

pub fn init(
    memory: Memory,
    video: Video,
    config: Config,
) Self {
    return .{
        // TODO: use constant.
        .pc = 0x200,
        .ir = 0,
        .vr = [_]u8{0} ** 16,
        .stack = Stack(16).init(),
        .memory = memory,
        .video = video,
        .delay_timer = 0,
        .sound_timer = 0,
        .version = config.version,
        .debug = config.debug,
    };
}

pub fn tick(self: *Self, keypad: Keypad) !void {
    const opcode = self.fetch();
    logger.debug("fetched opcode: {X:0>4}", .{opcode});
    try self.execute(opcode, keypad);
}

fn fetch(self: *Self) u16 {
    const opcode = @as(u16, self.memory[self.pc]) << 0x08 | @as(u16, self.memory[self.pc + 1]);
    self.pc += 2;
    return opcode;
}

pub fn execute(self: *Self, opcode: u16, keypad: Keypad) EmulatorError!void {
    const c: u4 = @intCast(opcode >> 0x0C);
    const x: u4 = @intCast((opcode & 0x0F00) >> 0x08);
    const y: u4 = @intCast((opcode & 0x00F0) >> 0x04);
    const n: u4 = @intCast(opcode & 0x000F);
    const nn: u8 = @intCast(opcode & 0x00FF);
    const nnn: u12 = @intCast(opcode & 0x0FFF);

    switch (c) {
        0x0 => {
            switch (opcode) {
                0x00E0 => self.execute_00E0(),
                0x00EE => try self.execute_00EE(),
                else => return EmulatorError.InvalidInstruction,
            }
        },
        0x1 => self.execute_1NNN(nnn),
        0x2 => try self.execute_2NNN(nnn),
        0x3 => self.execute_3NNN(x, nn),
        0x4 => self.execute_4NNN(x, nn),
        0x5 => self.execute_5XY0(x, y),
        0x6 => self.execute_6XNN(x, nn),
        0x7 => self.execute_7XNN(x, nn),
        0x8 => {
            switch (n) {
                0x0 => self.execute_8XY0(x, y),
                0x1 => self.execute_8XY1(x, y),
                0x2 => self.execute_8XY2(x, y),
                0x3 => self.execute_8XY3(x, y),
                0x4 => self.execute_8XY4(x, y),
                0x5 => self.execute_8XY5(x, y),
                0x6 => self.execute_8XY6(x, y),
                0x7 => self.execute_8XY7(x, y),
                0xE => self.execute_8XYE(x, y),
                else => return EmulatorError.InvalidInstruction,
            }
        },
        0x9 => self.execute_9XY0(x, y),
        0xA => self.execute_ANNN(nnn),
        0xB => self.execute_BNNN(x, nnn),
        0xC => self.execute_CXNN(x, nn),
        0xD => self.execute_DXYN(x, y, n),
        0xE => {
            switch (nn) {
                0x9E => try self.execute_EX9E(keypad, x),
                0xA1 => try self.execute_EXA1(keypad, x),
                else => return EmulatorError.InvalidInstruction,
            }
        },
        0xF => {
            switch (nn) {
                0x1E => self.execute_FX1E(x),
                0x07 => self.execute_FX07(x),
                0x15 => self.execute_FX15(x),
                0x18 => self.execute_FX18(x),
                else => return EmulatorError.InvalidInstruction,
            }
        },
    }
    self.video.render() catch {
        return EmulatorError.RenderingFailed;
    };
}

fn execute_0NNN(_: *Self) EmulatorError!void {
    return EmulatorError.UnsupportedInstruction;
}

fn execute_00E0(self: *Self) void {
    self.video.clear_screen();
}

fn execute_1NNN(self: *Self, pc: u16) void {
    self.pc = pc;
}

fn execute_00EE(self: *Self) !void {
    self.pc = self.stack.pop() catch {
        return EmulatorError.StackUnderflow;
    };
}

fn execute_2NNN(self: *Self, pc: u16) !void {
    self.stack.push(self.pc) catch {
        return EmulatorError.StackOverflow;
    };
    self.pc = pc;
}

fn execute_3NNN(self: *Self, register: u4, value: u8) void {
    self.skip_if(self.vr[register] == value);
}

fn execute_4NNN(self: *Self, register: u4, value: u8) void {
    self.skip_if(self.vr[register] != value);
}

fn execute_5XY0(self: *Self, register_x: u4, register_y: u4) void {
    self.skip_if(self.vr[register_x] == self.vr[register_y]);
}

fn execute_6XNN(self: *Self, register: u4, value: u8) void {
    self.vr[register] = value;
}

fn execute_7XNN(self: *Self, register: u4, value: u8) void {
    self.vr[register] +%= value;
}

fn execute_8XY0(self: *Self, register_x: u4, register_y: u4) void {
    self.vr[register_x] = self.vr[register_y];
}

fn execute_8XY1(self: *Self, register_x: u4, register_y: u4) void {
    self.vr[register_x] |= self.vr[register_y];
}

fn execute_8XY2(self: *Self, register_x: u4, register_y: u4) void {
    self.vr[register_x] &= self.vr[register_y];
}

fn execute_8XY3(self: *Self, register_x: u4, register_y: u4) void {
    self.vr[register_x] ^= self.vr[register_y];
}

fn execute_8XY4(self: *Self, register_x: u4, register_y: u4) void {
    const r = @addWithOverflow(self.vr[register_x], self.vr[register_y]);
    self.vr[register_x] = r[0];
    self.vr[0x0F] = r[1];
}

fn execute_8XY5(self: *Self, register_x: u4, register_y: u4) void {
    self.vr[0x0F] = 1;
    const r = @subWithOverflow(self.vr[register_x], self.vr[register_y]);
    self.vr[register_x] = r[0];
    self.vr[0x0F] -= r[1];
}

fn execute_8XY6(self: *Self, register_x: u4, register_y: u4) void {
    if (self.version == Version.COSMAC_VIP) {
        self.vr[register_x] = self.vr[register_y];
    }
    self.vr[0x0F] = self.vr[register_x] & 0x01;
    self.vr[register_x] >>= 1;
}

fn execute_8XY7(self: *Self, register_x: u4, register_y: u4) void {
    self.vr[0x0F] = 1;
    const r = @subWithOverflow(self.vr[register_y], self.vr[register_x]);
    self.vr[register_x] = r[0];
    self.vr[0x0F] -= r[1];
}

fn execute_8XYE(self: *Self, register_x: u4, register_y: u4) void {
    if (self.version == Version.COSMAC_VIP) {
        self.vr[register_x] = self.vr[register_y];
    }
    self.vr[0x0F] = (self.vr[register_x] & 0x80) >> 0x07;
    self.vr[register_x] <<= 1;
}

fn execute_9XY0(self: *Self, register_x: u4, register_y: u4) void {
    self.skip_if(self.vr[register_x] != self.vr[register_y]);
}

fn execute_ANNN(self: *Self, value: u12) void {
    self.ir = value;
}

fn execute_BNNN(self: *Self, register_x: u4, value: u12) void {
    if (self.version == Version.COSMAC_VIP) {
        self.pc = value + self.vr[0];
    } else {
        self.pc = value + self.vr[register_x];
    }
}

fn execute_CXNN(self: *Self, register_x: u4, value: u8) void {
    self.vr[register_x] = rand.int(u8) & value;
}

fn execute_DXYN(self: *Self, register_x: u4, register_y: u4, value: u4) void {
    self.vr[0x0F] = 0;
    for (0..value) |n| {
        const y = (self.vr[register_y] + n) % Video.HEIGHT;
        const pixels = self.memory[self.ir + n];
        for (0..8) |i| {
            const pixel: u1 = @intCast(pixels >> @intCast(0x07 - i) & 0x01);
            const x = (self.vr[register_x] + i) % Video.WIDTH;
            // TODO: use XOR.
            if (pixel > 0) {
                if (self.video.get_pixel(x, y) > 0) {
                    self.video.set_pixel(x, y, 0);
                    self.vr[0x0F] = 1;
                } else {
                    self.video.set_pixel(x, y, 1);
                }
            }
        }
    }
}

fn execute_EX9E(self: *Self, keypad: Keypad, register_x: u4) !void {
    self.skip_if(keypad[self.vr[register_x]]);
}

fn execute_EXA1(self: *Self, keypad: Keypad, register_x: u4) !void {
    self.skip_if(!keypad[self.vr[register_x]]);
}

fn execute_FX1E(self: *Self, register_x: u4) void {
    if (self.version == Version.COSMAC_VIP) {
        self.ir +%= self.vr[register_x];
    } else {
        const r = @addWithOverflow(self.ir, self.vr[register_x]);
        self.ir += r[0];
        self.vr[0x0F] = r[1];
    }
}

fn execute_FX07(self: *Self, register_x: u4) void {
    self.vr[register_x] = self.delay_timer;
}

fn execute_FX15(self: *Self, register_x: u4) void {
    self.delay_timer = self.vr[register_x];
}

fn execute_FX18(self: *Self, register_x: u4) void {
    self.sound_timer = self.vr[register_x];
}

fn skip_if(self: *Self, condition: bool) void {
    if (condition) {
        self.pc += 2;
    }
}
