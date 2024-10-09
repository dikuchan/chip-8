const std = @import("std");
const eql = std.mem.eql;

const Version = @import("./core/version.zig").Version;

const ParserError = error{
    ParseError,
    NotFound,
};

const Parser = struct {
    const Self = @This();

    args: []const [:0]u8,

    fn init(allocator: std.mem.Allocator) !Self {
        const args = try std.process.argsAlloc(allocator);
        return .{ .args = args };
    }

    fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        std.process.argsFree(allocator, self.args);
    }

    fn parseArg(self: *Self, n: usize, default: ?[]const u8) ParserError![]const u8 {
        if (n > self.args.len) {
            if (default) |value| {
                return value;
            }
            return ParserError.NotFound;
        }
        return self.args[n];
    }

    fn parseFlag(self: *Self, name: []const u8, default: ?bool) ParserError!bool {
        var flag = default;
        for (self.args) |arg| {
            if (eql(u8, arg, name)) {
                flag = true;
            }
        }
        if (flag) |value| {
            return value;
        }
        return ParserError.NotFound;
    }

    fn parseOption(self: *Self, name: []const u8, default: ?[]const u8) ParserError![]const u8 {
        for (self.args, 0..) |arg, i| {
            if (eql(u8, arg, name)) {
                if (self.args.len <= i) {
                    return ParserError.ParseError;
                }
                return self.args[i + 1];
            }
        }
        if (default) |value| {
            return value;
        }
        return ParserError.NotFound;
    }
};

const CliError = error{
    UnknownVersion,
};

pub const Cli = struct {
    const Self = @This();

    parser: Parser,

    file: []const u8,
    debug: bool,
    version: Version,
    fps: u32,

    pub fn init(allocator: std.mem.Allocator) !Cli {
        var parser = try Parser.init(allocator);
        return .{
            .parser = parser,
            .file = try parser.parseArg(1, null),
            .debug = try parser.parseFlag("--debug", false),
            .version = try parseVersion(try parser.parseOption("--version", null)),
            .fps = try std.fmt.parseInt(u32, try parser.parseOption("--fps", "120"), 10),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.parser.deinit(allocator);
    }
};

fn parseVersion(s: []const u8) CliError!Version {
    for ([_]Version{
        Version.COSMAC_VIP,
        Version.SUPER_CHIP,
    }) |version| {
        if (eql(u8, @tagName(version), s)) {
            return version;
        }
    }
    return CliError.UnknownVersion;
}
