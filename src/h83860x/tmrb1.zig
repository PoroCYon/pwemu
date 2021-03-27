
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;

pub const TmrB1 = struct { // IO1
    sys: *H838606F,

    tmb1: u8,
    tcb1: u8,
    tlb1: u8,

    pub fn init(s: *H838606F) TmrB1 {
        return TmrB1 { .sys = s, .tmb1 = 0, .tcb1 = 0, .tlb1 = 0 };
    }
    pub fn reset(self: *TmrB1) void {
        self.tmb1 = 0;
        self.tcb1 = 0;
        self.tlb1 = 0;
    }

    pub fn write8 (self: *TmrB1, off: usize, v: u8 ) void {
        std.debug.print("write8 TMRB1 unknown 0x{x:} <- 0x{x:}\n", .{off,v});
        self.sys.sched.ibreak();
    }
    pub inline fn write16(self: *TmrB1, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *TmrB1, off: usize) u8  {
        std.debug.print("read8 TMRB1 unknown 0x{x:}\n", .{off});
        self.sys.sched.ibreak();
        return 0;
    }
    pub inline fn read16(self: *TmrB1, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

