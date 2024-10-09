const std = @import("std");
const rand = std.crypto.random;

const Stack = @import("./stack.zig").Stack;
const Version = @import("./version.zig").Version;
const Screen = @import("./Screen.zig");
const Key = @import("./Keypad.zig").Key;

const PROGRAM_OFFSET = @import("./memory.zig").PROGRAM_OFFSET;
const FONT_OFFSET = @import("./memory.zig").FONT_OFFSET;
const MEMORY_SIZE = @import("./memory.zig").MEMORY_SIZE;

const STACK_SIZE = 16;
const REGISTER_COUNT = 16;
const KEYPAD_SIZE = 16;

pub const SCREEN_WIDTH = 64;
pub const SCREEN_HEIGHT = 32;

const logger = std.log.scoped(.emu);

pub const EmulatorError = error{
    InvalidInstruction,
    UnsupportedInstruction,
    StackOverflow,
    StackUnderflow,
    RenderingFailed,
};

const Config = struct {
    version: Version,
    debug: bool,
};

const Self = @This();

pc: u16,
ir: u16,
vr: [REGISTER_COUNT]u8,
stack: Stack(STACK_SIZE),

memory: [MEMORY_SIZE]u8,
screen: [SCREEN_WIDTH][SCREEN_HEIGHT]u1,
keypad: [KEYPAD_SIZE]bool,

delay_timer: u8,
sound_timer: u8,

config: Config,

pub fn init(memory: [MEMORY_SIZE]u8, config: Config) Self {
    var screen: [SCREEN_WIDTH][SCREEN_HEIGHT]u1 = undefined;
    for (0..SCREEN_WIDTH) |i| {
        screen[i] = [_]u1{0} ** SCREEN_HEIGHT;
    }
    return .{
        .pc = PROGRAM_OFFSET,
        .ir = 0,
        .vr = [_]u8{0} ** REGISTER_COUNT,
        .stack = Stack(STACK_SIZE).init(),
        .memory = memory,
        .screen = screen,
        .keypad = [_]bool{false} ** KEYPAD_SIZE,
        .delay_timer = 0,
        .sound_timer = 0,
        .config = config,
    };
}

pub fn tick(self: *Self) EmulatorError!void {
    const opcode = self.fetch();
    logger.debug("fetched opcode: {X:0>4}", .{opcode});
    try self.execute(opcode);
}

pub fn hztick(self: *Self) void {
    if (self.delay_timer > 0) {
        self.delay_timer -= 1;
    }
    if (self.sound_timer > 0) {
        self.sound_timer -= 1;
    }
}

fn fetch(self: *Self) u16 {
    const opcode = @as(u16, self.memory[self.pc]) << 0x08 | @as(u16, self.memory[self.pc + 1]);
    self.pc += 2;
    return opcode;
}

fn execute(self: *Self, opcode: u16) EmulatorError!void {
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
                0x9E => try self.execute_EX9E(x),
                0xA1 => try self.execute_EXA1(x),
                else => return EmulatorError.InvalidInstruction,
            }
        },
        0xF => {
            switch (nn) {
                0x07 => self.execute_FX07(x),
                0x0A => self.execute_FX0A(x),
                0x15 => self.execute_FX15(x),
                0x18 => self.execute_FX18(x),
                0x1E => self.execute_FX1E(x),
                0x29 => self.execute_FX29(x),
                0x33 => self.execute_FX33(x),
                0x55 => self.execute_FX55(x),
                0x65 => self.execute_FX65(x),
                else => return EmulatorError.InvalidInstruction,
            }
        },
    }
}

fn execute_0NNN(_: *Self) EmulatorError!void {
    return EmulatorError.UnsupportedInstruction;
}

fn execute_00E0(self: *Self) void {
    for (0..SCREEN_WIDTH) |x| {
        for (0..SCREEN_HEIGHT) |y| {
            self.screen[x][y] = 0;
        }
    }
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
    self.skipIf(self.vr[register] == value);
}

fn execute_4NNN(self: *Self, register: u4, value: u8) void {
    self.skipIf(self.vr[register] != value);
}

fn execute_5XY0(self: *Self, register_x: u4, register_y: u4) void {
    self.skipIf(self.vr[register_x] == self.vr[register_y]);
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
    if (self.config.version == Version.COSMAC_VIP) {
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
    if (self.config.version == Version.COSMAC_VIP) {
        self.vr[register_x] = self.vr[register_y];
    }
    self.vr[0x0F] = (self.vr[register_x] & 0x80) >> 0x07;
    self.vr[register_x] <<= 1;
}

fn execute_9XY0(self: *Self, register_x: u4, register_y: u4) void {
    self.skipIf(self.vr[register_x] != self.vr[register_y]);
}

fn execute_ANNN(self: *Self, value: u12) void {
    self.ir = value;
}

fn execute_BNNN(self: *Self, register_x: u4, value: u12) void {
    if (self.config.version == Version.COSMAC_VIP) {
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
        const y = (self.vr[register_y] + n) % SCREEN_HEIGHT;
        const pixels = self.memory[self.ir + n];
        for (0..8) |i| {
            const pixel: u1 = @intCast(pixels >> @intCast(0x07 - i) & 0x01);
            const x = (self.vr[register_x] + i) % SCREEN_WIDTH;
            // TODO: use XOR.
            if (pixel > 0) {
                if (self.screen[x][y] > 0) {
                    self.screen[x][y] = 0;
                    self.vr[0x0F] = 1;
                } else {
                    self.screen[x][y] = 1;
                }
            }
        }
    }
}

fn execute_EX9E(self: *Self, register_x: u4) !void {
    self.skipIf(self.keypad[self.vr[register_x]]);
}

fn execute_EXA1(self: *Self, register_x: u4) !void {
    self.skipIf(!self.keypad[self.vr[register_x]]);
}

fn execute_FX07(self: *Self, register_x: u4) void {
    self.vr[register_x] = self.delay_timer;
}

fn execute_FX0A(self: *Self, register_x: u4) void {
    var value: ?u8 = null;
    for (self.keypad, 0..) |key, i| {
        if (key) {
            value = @intCast(i);
            break;
        }
    }
    if (value) |v| {
        self.vr[register_x] = v;
    }
}

fn execute_FX15(self: *Self, register_x: u4) void {
    self.delay_timer = self.vr[register_x];
}

fn execute_FX18(self: *Self, register_x: u4) void {
    self.sound_timer = self.vr[register_x];
}

fn execute_FX1E(self: *Self, register_x: u4) void {
    if (self.config.version == Version.COSMAC_VIP) {
        self.ir +%= self.vr[register_x];
    } else {
        const r = @addWithOverflow(self.ir, self.vr[register_x]);
        self.ir += r[0];
        self.vr[0x0F] = r[1];
    }
}

fn execute_FX29(self: *Self, register_x: u4) void {
    self.ir = FONT_OFFSET + (5 * self.vr[register_x]);
}

fn execute_FX33(self: *Self, register_x: u4) void {
    self.memory[self.ir] = self.vr[register_x] / 100;
    self.memory[self.ir + 1] = (self.vr[register_x] % 100) / 10;
    self.memory[self.ir + 2] = self.vr[register_x] % 10;
}

fn execute_FX55(self: *Self, register_x: u4) void {
    for (0..register_x + 1) |i| {
        self.memory[self.ir + i] = self.vr[i];
        if (self.config.version == Version.COSMAC_VIP) {
            self.ir += 1;
        }
    }
}

fn execute_FX65(self: *Self, register_x: u4) void {
    for (0..register_x + 1) |i| {
        self.vr[i] = self.memory[self.ir + i];
        if (self.config.version == Version.COSMAC_VIP) {
            self.ir += 1;
        }
    }
}

fn skipIf(self: *Self, condition: bool) void {
    if (condition) {
        self.pc += 2;
    }
}

pub fn pressKey(self: *Self, key: Key) void {
    self.keypad[key.index()] = true;
}

pub fn releaseKey(self: *Self, key: Key) void {
    self.keypad[key.index()] = false;
}

pub fn draw(self: *Self, screen: Screen) !void {
    for (0..SCREEN_WIDTH) |x| {
        for (0..SCREEN_HEIGHT) |y| {
            if (self.screen[x][y] == 0) {
                try screen.fillBlock(x, y, Screen.Color.black);
            } else {
                try screen.fillBlock(x, y, Screen.Color.white);
            }
        }
    }
    try screen.render();
}
