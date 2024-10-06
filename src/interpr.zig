const std = @import("std");

const Stack = @import("./stack.zig").Stack;
const load_file = @import("./data.zig").load_file;

const Instr = union(enum) {
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
        size: u4,
    },
    unknown,
};

pub const InterprError = error{
    InvalidOpcode,
    InvalidInstr,
};

pub const Interpr = struct {
    // RAM.
    data: [4096]u8,
    // Program counter.
    pc: u16,
    // `I` register.
    ir: u16,
    // Variable registers.
    vr: [16]u8,
    stack: Stack(16),

    fn fetch(self: *Interpr) !u16 {
        const n1 = @as(u16, self.data[self.pc]) << 0x8;
        const n2 = @as(u16, self.data[self.pc + 1]);
        self.pc += 2;
        return n1 | n2;
    }

    fn decode(opcode: u16) !Instr {
        const c: u4 = @intCast(opcode >> 12);
        const x: u4 = @intCast(opcode >> 8 & 0x0F);
        const y: u4 = @intCast(opcode >> 4 & 0x00F);
        const n: u4 = @intCast(opcode & 0x000F);
        const nn: u8 = @intCast(opcode & 0x00FF);
        const nnn: u12 = @intCast(opcode & 0x0FFF);

        return switch (c) {
            0x0 => {
                return switch (opcode) {
                    0x00E0 => Instr.clear_screen,
                    0x00EE => Instr.unknown,
                    else => Instr.unknown,
                };
            },
            0x1 => Instr{
                .jump = nnn,
            },
            0x6 => Instr{
                .set = .{
                    .register = x,
                    .value = nn,
                },
            },
            0x7 => Instr{
                .add = .{
                    .register = x,
                    .value = nn,
                },
            },
            0xA => Instr{
                .set_ir = nnn,
            },
            0xD => Instr{
                .draw = .{
                    .x = x,
                    .y = y,
                    .size = n,
                },
            },
            else => InterprError.InvalidInstr,
        };
    }

    fn execute(self: *Interpr, instr: Instr) !void {
        switch (instr) {
            .clear_screen => {},
            .jump => |pc| {
                self.pc = pc;
            },
            .set => |i| {
                self.vr[i.register] = i.value;
            },
            .set_ir => |ir| {
                self.ir = ir;
            },
            .add => |i| {
                self.vr[i.register] += i.value;
            },
            .draw => |_| {},
            .unknown => |_| {
                return InterprError.InvalidInstr;
            },
        }
    }

    pub fn tick(self: *Interpr) !void {
        const opcode = try self.fetch();
        std.log.debug("opcode: {X}", .{opcode});
        const instr = try decode(opcode);
        std.log.debug("instruction: {any}", .{instr});
        try self.execute(instr);
    }
};

pub fn load(file_path: []const u8) !Interpr {
    const data = try load_file(file_path);
    return Interpr{
        .data = data,
        .pc = 512,
        .ir = 0,
        .vr = [_]u8{0} ** 16,
        .stack = Stack(16).init(),
    };
}
