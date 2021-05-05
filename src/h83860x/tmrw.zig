
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;

pub const TmrW = struct { // IO1
    sys: *H838606F,

    tmrw: u8, // f0f0
    tcrw: u8, // f0f1
    tierw: u8, // f0f2
    tsrw: u8, // f0f3
    tior0: u8, // f0f4
    tior1: u8, // f0f5
    tcnt: u16, // f0f6
    gra: u16, grb: u16, grc: u16, grd: u16, // f0f8..f0ff

    pub fn init(s: *H838606F) TmrW {
        return TmrW { .sys = s,
            .tmrw = 0, .tcrw = 0, .tierw = 0, .tsrw = 0,
            .tior0 = 0, .tior1 = 0, .tcnt = 0,
            .gra = 0, .grb = 0, .grc = 0, .grd = 0 };
    }
    pub fn reset(self: *TmrW) void {
        self.tmrw = 0;
        self.tcrw = 0;
        self.tierw = 0;
        self.tsrw = 0;
        self.tior0 = 0;
        self.tior1 = 0;
        self.tcnt = 0;
        self.gra = 0xffff;
        self.grb = 0xffff;
        self.grc = 0xffff;
        self.grd = 0xffff;
    }

    pub fn write8 (self: *TmrW, off: usize, v: u8 ) void {
        std.debug.print("write8 TMRW unknown 0x{x:} <- 0x{x:}\n", .{off,v});
        self.sys.sched.ibreak();
    }
    pub fn write16(self: *TmrW, off: usize, v: u16) void {
        std.debug.print("write16 TMRW unknown 0x{x:} <- 0x{x:}\n", .{off,v});
        self.sys.sched.ibreak();
    }

    pub fn read8 (self: *TmrW, off: usize) u8  {
        std.debug.print("read8 TMRW unknown 0x{x:}\n", .{off});
        self.sys.sched.ibreak();
        return 0;
    }
    pub fn read16(self: *TmrW, off: usize) u16 {
        std.debug.print("read16 TMRW unknown 0x{x:}\n", .{off});
        self.sys.sched.ibreak();
        return 0;
    }
};

