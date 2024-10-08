const std = @import("std");
const rand = std.crypto.random;

const Keypad = @import("./driver/Keypad.zig");
const Memory = @import("./memory.zig").Memory;
const Stack = @import("./stack.zig").Stack;
const Version = @import("./version.zig").Version;
const Video = @import("./driver/Video.zig");

const logger = std.log.scoped(.emulator);

pub const EmulatorError = error{
    InvalidOpcode,
};

const Self = @This();

pc: u16,
ir: u16,
vr: [16]u8,
stack: Stack(16),
memory: Memory,

// Drivers.
keypad: Keypad,
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
    keypad: Keypad,
    video: Video,
    config: Config,
) Self {
    return .{
        // TODO: use memory size.
        .pc = 0x200,
        .ir = 0,
        .vr = [_]u8{0} ** 16,
        .stack = Stack(16).init(),
        .memory = memory,
        .keypad = keypad,
        .video = video,
        .delay_timer = 0,
        .sound_timer = 0,
        .version = config.version,
        .debug = config.debug,
    };
}

pub fn tick(self: *Self) !void {
    const opcode = self.fetch();
    logger.debug("fetched opcode: {X:0>4}", .{opcode});
    const instruction = try decode(opcode);
    try self.execute(instruction);
}

fn fetch(self: *Self) u16 {
    const opcode = @as(u16, self.memory[self.pc]) << 0x08 | @as(u16, self.memory[self.pc + 1]);
    self.pc += 2;
    return opcode;
}

const Operation = struct {
    register_x: u4,
    register_y: u4,
};

const Instruction = union(enum) {
    add: struct {
        register: u4,
        value: u8,
    },
    add_ir: u4,
    clear_screen,
    set_delay_timer_to_x: u4,
    set_x_to_delay_timer: u4,
    set_sound_timer_to_x: u4,
    draw: struct {
        register_x: u4,
        register_y: u4,
        n: u4,
    },
    jump: u16,
    jump_offset: struct {
        register_x: u4,
        value: u12,
    },
    operation_set: Operation,
    operation_or: Operation,
    operation_and: Operation,
    operation_xor: Operation,
    operation_add: Operation,
    operation_sub_xy: Operation,
    operation_sub_yx: Operation,
    operation_shr: Operation,
    operation_shl: Operation,
    random: struct {
        register_x: u4,
        value: u8,
    },
    set: struct {
        register: u4,
        value: u8,
    },
    set_ir: u16,
    skip_eq: struct {
        register: u4,
        value: u8,
    },
    skip_ne: struct {
        register: u4,
        value: u8,
    },
    skip_register_eq: struct {
        register_x: u4,
        register_y: u4,
    },
    skip_register_ne: struct {
        register_x: u4,
        register_y: u4,
    },
    skip_if_key_pressed: u4,
    skip_if_key_not_pressed: u4,
    subroutine_call: u16,
    subroutine_return,
};

pub fn decode(opcode: u16) EmulatorError!Instruction {
    const c: u4 = @intCast(opcode >> 0x0C);
    const x: u4 = @intCast((opcode & 0x0F00) >> 0x08);
    const y: u4 = @intCast((opcode & 0x00F0) >> 0x04);
    const n: u4 = @intCast(opcode & 0x000F);
    const nn: u8 = @intCast(opcode & 0x00FF);
    const nnn: u12 = @intCast(opcode & 0x0FFF);

    return switch (c) {
        0x0 => {
            return switch (opcode) {
                0x00E0 => Instruction.clear_screen,
                0x00EE => Instruction.subroutine_return,
                else => EmulatorError.InvalidOpcode,
            };
        },
        0x1 => .{ .jump = nnn },
        0x2 => .{ .subroutine_call = nnn },
        0x3 => .{
            .skip_eq = .{
                .register = x,
                .value = nn,
            },
        },
        0x4 => .{
            .skip_ne = .{
                .register = x,
                .value = nn,
            },
        },
        0x5 => .{
            .skip_register_eq = .{
                .register_x = x,
                .register_y = y,
            },
        },
        0x6 => .{
            .set = .{
                .register = x,
                .value = nn,
            },
        },
        0x7 => .{
            .add = .{
                .register = x,
                .value = nn,
            },
        },
        0x8 => {
            const operation = Operation{
                .register_x = x,
                .register_y = y,
            };
            return switch (n) {
                0x0 => .{ .operation_set = operation },
                0x1 => .{ .operation_or = operation },
                0x2 => .{ .operation_and = operation },
                0x3 => .{ .operation_xor = operation },
                0x4 => .{ .operation_add = operation },
                0x5 => .{ .operation_sub_xy = operation },
                0x6 => .{ .operation_shr = operation },
                0x7 => .{ .operation_sub_yx = operation },
                0xE => .{ .operation_shl = operation },
                else => EmulatorError.InvalidOpcode,
            };
        },
        0x9 => .{
            .skip_register_ne = .{
                .register_x = x,
                .register_y = y,
            },
        },
        0xA => .{ .set_ir = nnn },
        0xB => .{
            .jump_offset = .{
                .register_x = x,
                .value = nnn,
            },
        },
        0xC => .{
            .random = .{
                .register_x = x,
                .value = nn,
            },
        },
        0xD => .{
            .draw = .{
                .register_x = x,
                .register_y = y,
                .n = n,
            },
        },
        0xE => {
            return switch (nn) {
                0x9E => .{ .skip_if_key_pressed = x },
                0xA1 => .{ .skip_if_key_not_pressed = x },
                else => EmulatorError.InvalidOpcode,
            };
        },
        0xF => {
            return switch (nn) {
                0x1E => .{ .add_ir = x },
                0x07 => .{ .set_x_to_delay_timer = x },
                0x15 => .{ .set_delay_timer_to_x = x },
                0x18 => .{ .set_sound_timer_to_x = x },
                else => EmulatorError.InvalidOpcode,
            };
        },
    };
}

fn execute(self: *Self, instruction: Instruction) !void {
    switch (instruction) {
        .add => |ix| {
            self.vr[ix.register] +%= ix.value;
        },
        .add_ir => |x| {
            if (self.version == Version.COSMAC_VIP) {
                self.ir +%= self.vr[x];
            } else {
                const r = @addWithOverflow(self.ir, self.vr[x]);
                self.ir += r[0];
                self.vr[0x0F] = r[1];
            }
        },
        .clear_screen => {
            self.video.clear_screen();
        },
        .draw => |ix| {
            self.vr[0x0F] = 0;
            for (0..ix.n) |n| {
                const y = (self.vr[ix.register_y] + n) % Video.HEIGHT;
                const pixels = self.memory[self.ir + n];
                for (0..8) |i| {
                    const pixel: u1 = @intCast(pixels >> @intCast(0x07 - i) & 0x01);
                    const x = (self.vr[ix.register_x] + i) % Video.WIDTH;
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
        },
        .jump => |pc| {
            self.pc = pc;
        },
        .jump_offset => |ix| {
            if (self.version == Version.COSMAC_VIP) {
                self.pc = ix.value + self.vr[0];
            } else {
                self.pc = ix.value + self.vr[ix.register_x];
            }
        },
        .operation_set => |ix| {
            self.vr[ix.register_x] = self.vr[ix.register_y];
        },
        .operation_or => |ix| {
            self.vr[ix.register_x] |= self.vr[ix.register_y];
        },
        .operation_and => |ix| {
            self.vr[ix.register_x] &= self.vr[ix.register_y];
        },
        .operation_xor => |ix| {
            self.vr[ix.register_x] ^= self.vr[ix.register_y];
        },
        .operation_add => |ix| {
            const r = @addWithOverflow(self.vr[ix.register_x], self.vr[ix.register_y]);
            self.vr[ix.register_x] = r[0];
            self.vr[0x0F] = r[1];
        },
        .operation_sub_xy => |ix| {
            self.vr[0x0F] = 1;
            const r = @subWithOverflow(self.vr[ix.register_x], self.vr[ix.register_y]);
            self.vr[ix.register_x] = r[0];
            self.vr[0x0F] -= r[1];
        },
        .operation_sub_yx => |ix| {
            self.vr[0x0F] = 1;
            const r = @subWithOverflow(self.vr[ix.register_y], self.vr[ix.register_x]);
            self.vr[ix.register_x] = r[0];
            self.vr[0x0F] -= r[1];
        },
        .operation_shr => |ix| {
            if (self.version == Version.COSMAC_VIP) {
                self.vr[ix.register_x] = self.vr[ix.register_y];
            }
            self.vr[0x0F] = self.vr[ix.register_x] & 0x01;
            self.vr[ix.register_x] >>= 1;
        },
        .operation_shl => |ix| {
            if (self.version == Version.COSMAC_VIP) {
                self.vr[ix.register_x] = self.vr[ix.register_y];
            }
            self.vr[0x0F] = (self.vr[ix.register_x] & 0x80) >> 0x07;
            self.vr[ix.register_x] <<= 1;
        },
        .random => |ix| {
            self.vr[ix.register_x] = rand.int(u8) & ix.value;
        },
        .set => |ix| {
            self.vr[ix.register] = ix.value;
        },
        .set_ir => |ir| {
            self.ir = ir;
        },
        .set_delay_timer_to_x => |x| {
            self.delay_timer = self.vr[x];
        },
        .set_x_to_delay_timer => |x| {
            self.vr[x] = self.delay_timer;
        },
        .set_sound_timer_to_x => |x| {
            self.sound_timer = self.vr[x];
        },
        .skip_eq => |ix| {
            self.skip_if(self.vr[ix.register] == ix.value);
        },
        .skip_ne => |ix| {
            self.skip_if(self.vr[ix.register] != ix.value);
        },
        .skip_register_eq => |ix| {
            self.skip_if(self.vr[ix.register_x] == self.vr[ix.register_y]);
        },
        .skip_register_ne => |ix| {
            self.skip_if(self.vr[ix.register_x] != self.vr[ix.register_y]);
        },
        .skip_if_key_pressed => |x| {
            const keypad = try self.keypad.poll();
            self.skip_if(keypad[self.vr[x]]);
        },
        .skip_if_key_not_pressed => |x| {
            const keypad = try self.keypad.poll();
            self.skip_if(!keypad[self.vr[x]]);
        },
        .subroutine_call => |pc| {
            try self.stack.push(self.pc);
            self.pc = pc;
        },
        .subroutine_return => {
            self.pc = try self.stack.pop();
        },
    }
    try self.video.render();
}

fn skip_if(self: *Self, condition: bool) void {
    if (condition) {
        self.pc += 2;
    }
}
