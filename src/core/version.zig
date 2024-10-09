/// Version of a device with the CHIP-8 interpreter.
///
/// Behavior of many instructions depends on the device version.
pub const Version = enum {
    COSMAC_VIP,
    SUPER_CHIP,
};
