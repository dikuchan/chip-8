const std = @import("std");

pub const StackError = error{
    Empty,
    Full,
};

pub fn Stack(comptime size: usize) type {
    return struct {
        data: [size]u16,
        idx: usize,

        const Self = @This();

        pub fn init() Self {
            return .{
                .data = [_]u16{0} ** size,
                .idx = 0,
            };
        }

        pub fn push(self: *Self, value: u16) StackError!void {
            if (self.idx == size) {
                return StackError.Full;
            }
            self.data[self.idx] = value;
            self.idx += 1;
        }

        pub fn pop(self: *Self) StackError!u16 {
            if (self.idx == 0) {
                return StackError.Empty;
            }
            self.idx -= 1;
            return self.data[self.idx];
        }
    };
}

const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

test "stack" {
    const size = comptime 16;
    var stack = Stack(size).init();

    var i: u16 = 0;
    while (i < size) : (i += 1) {
        try stack.push(i);
    }
    try expectError(StackError.Full, stack.push(size + 1));

    try expectEqual(i, 16);

    while (i > 0) : (i -= 1) {
        try expectEqual(i - 1, try stack.pop());
    }
    try expectError(StackError.Empty, stack.pop());
}
