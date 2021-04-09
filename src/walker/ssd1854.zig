
const std = @import("std");

const Walker = @import("../walker.zig").Walker;

pub const Ssd1854 = struct {
    sys: *Walker,

    pub fn init(s: *Walker) Ssd1854 {
        return Ssd1854 { .sys = s };
    }
    pub fn reset(self: *Ssd1854) void {

    }

    pub fn write(self: *Ssd1854, mode: u1, v: u8) void {
        std.debug.print("W: SSD1854 write mode={} val=0x{x:}\n", .{mode, v});
    }
};

