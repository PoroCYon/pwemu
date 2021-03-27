
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;

pub const Adc = struct { // IO2
    sys: *H838606F,

    adrr: u16, // don't init this on reset!
    amr: u8,
    adsr: u8,

    pub fn init(s: *H838606F) Adc {
        return Adc { .sys = s, .adrr = undefined, .amr = 0, .adsr = 0 };
    }
    pub fn reset(self: *Adc) void {
        self.amr = 0;
        self.adsr = 0;
    }

    pub fn write8 (self: *Adc, off: usize, v: u8 ) void {
        std.debug.print("write8 ADC unknown 0x{x:} <- 0x{x:}\n", .{off,v});
        self.sys.sched.ibreak();
    }
    pub fn write16(self: *Adc, off: usize, v: u16) void {
        std.debug.print("write16 ADC unknown 0x{x:} <- 0x{x:}\n", .{off,v});
        self.sys.sched.ibreak();
    }

    pub fn read8 (self: *Adc, off: usize) u8  {
        std.debug.print("read8 ADC unknown 0x{x:}\n", .{off});
        self.sys.sched.ibreak();
        return 0;
    }
    pub fn read16(self: *Adc, off: usize) u16 {
        std.debug.print("read16 ADC unknown 0x{x:}\n", .{off});
        self.sys.sched.ibreak();
        return 0;
    }
};

