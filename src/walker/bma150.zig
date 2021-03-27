
const std = @import("std");

const Walker = @import("../walker.zig").Walker;

pub const Bma150 = struct { // IO1
    sys: *Walker,

    pub fn init(s: *Walker) Bma150 {
        return Bma150 { .sys = s };
    }
    pub fn reset(self: *Bma150) void {

    }

    pub fn read(self: *Bma150) u8 {
        return 0;
    }
    pub fn write(self: *Bma150, v: u8) void {
        
    }
};

