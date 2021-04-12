
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;

pub const Adc = struct { // IO2
    sys: *H838606F,

    adrr: u10, // don't init this on reset!
    amr: u7,
    adsr: u2,

    pub fn init(s: *H838606F) Adc {
        return Adc { .sys = s, .adrr = undefined, .amr = 0, .adsr = 0 };
    }
    pub fn reset(self: *Adc) void {
        self.amr = 0;
        self.adsr = 0;
    }

    pub fn write8 (self: *Adc, off: usize, v: u8 ) void {
        switch (off) {
            0xffbe => { self.amr  = @truncate(u7,v); },
            0xffbf => { self.adsr = @truncate(u2,v>>6); },
            else => {
                std.debug.print("write8 ADC unknown 0x{x:} <- 0x{x:}\n", .{off,v});
                self.sys.sched.ibreak();
            }
        }
    }
    pub fn write16(self: *Adc, off: usize, v: u16) void {
        std.debug.print("write16 ADC unknown 0x{x:} <- 0x{x:}\n", .{off,v});
        self.sys.sched.ibreak();
    }

    pub fn read8 (self: *Adc, off: usize) u8  {
        return switch (off) {
            0xffbe => @as(u8,self.amr ),
            0xffbf => @truncate(u8,@as(u8,self.adsr&1)<<6), // always read the ADSF bit as 0, so ADCs happen instantly
            else => blk: {
                std.debug.print("read8 ADC unknown 0x{x:}\n", .{off});
                self.sys.sched.ibreak();
                break :blk 0;
            }
        };
    }
    pub fn read16(self: *Adc, off: usize) u16 {
        if (off == 0xffbc) {
            return @truncate(u16,@as(u16,self.adrr)<<6);
        } else if (off == 0xffbe) {
            return (@as(u16,self.amr)<<8)
                 |  @as(u16,@truncate(u8,@as(u8,self.adsr)<<6));
        } else {
            std.debug.print("read16 ADC unknown 0x{x:}\n", .{off});
            self.sys.sched.ibreak();
            return 0;
        }
    }
};

