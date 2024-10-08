pub const Version = enum {
    COSMAC_VIP,
    SUPER_CHIP,

    pub fn toString(version: Version) []const u8 {
        return switch (version) {
            .COSMAC_VIP => "COSMAC_VIP",
            .SUPER_CHIP => "SUPER_CHIP",
        };
    }
};
