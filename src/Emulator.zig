const std = @import("std");

const Memory = @import("./memory.zig").Memory;
const Video = @import("./driver/Video.zig");
const Stack = @import("./stack.zig").Stack;

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
video: *Video,

pub fn init(memory: Memory, video: *Video) Self {
    return .{
        // TODO: use memory size.
        .pc = 0x200,
        .ir = 0,
        .vr = [_]u8{0} ** 16,
        .stack = Stack(16).init(),
        .memory = memory,
        .video = video,
    };
}

pub fn fetch(self: *Self) u16 {
    const opcode = @as(u16, self.memory[self.pc]) << 0x08 | @as(u16, self.memory[self.pc + 1]);
    self.pc += 2;
    return opcode;
}

const Instruction = union(enum) {
    clear_screen,
    jump: u16,
    set: struct {
        register: usize,
        value: u8,
    },
    set_ir: u16,
    add: struct {
        register: usize,
        value: u8,
    },
    draw: struct {
        x: u4,
        y: u4,
        n: u4,
    },
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
                0x00EE => EmulatorError.InvalidOpcode,
                else => EmulatorError.InvalidOpcode,
            };
        },
        0x1 => Instruction{
            .jump = nnn,
        },
        0x6 => Instruction{
            .set = .{
                .register = x,
                .value = nn,
            },
        },
        0x7 => Instruction{
            .add = .{
                .register = x,
                .value = nn,
            },
        },
        0xA => Instruction{
            .set_ir = nnn,
        },
        0xD => Instruction{
            .draw = .{
                .x = x,
                .y = y,
                .n = n,
            },
        },
        else => EmulatorError.InvalidOpcode,
    };
}

fn execute(self: *Self, instruction: Instruction) !void {
    switch (instruction) {
        .clear_screen => {
            self.video.clear_screen();
        },
        .jump => |pc| {
            self.pc = pc;
        },
        .set => |ix| {
            self.vr[ix.register] = ix.value;
        },
        .set_ir => |ir| {
            self.ir = ir;
        },
        .add => |ix| {
            self.vr[ix.register] += ix.value;
        },
        .draw => |ix| {
            self.vr[0x0F] = 0;
            for (0..ix.n) |n| {
                const y = (self.vr[ix.y] + n) % Video.HEIGHT;
                const pixels = self.memory[self.ir + n];
                for (0..8) |i| {
                    const pixel: u1 = @intCast(pixels >> @intCast(0x07 - i) & 0x01);
                    const x = (self.vr[ix.x] + i) % Video.WIDTH;
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
    }
    try self.video.render();
}

pub fn tick(self: *Self) !void {
    const opcode = self.fetch();
    logger.debug("fetched opcode: {X:0>4}", .{opcode});
    const instruction = try decode(opcode);
    try self.execute(instruction);
}
