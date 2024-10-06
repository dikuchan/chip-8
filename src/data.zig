const std = @import("std");

pub fn load_file(path: []const u8) ![4096]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var buffer: [4096]u8 = [_]u8{0} ** 4096;
    const n = try file.readAll(buffer[512..]);
    std.log.info("read file: {d}", .{n});
    return buffer;
}
