
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;

pub const Rtc = struct { // IO1
    sys: *H838606F,

    rtcflg: u8,
    fsecdr: u8,
    fmindr: u8,
    fhrdr: u8,
    rwkdr: u8,
    rtccr1: u8,
    rtccr2: u8,
    rtcscr: u8,

    pub fn init(s: *H838606F) Rtc {
        return Rtc { .sys = s, .rtcflg = undefined,
            .fsecdr = undefined, .fmindr = undefined, .fhrdr = undefined,
            .rwkdr = undefined, .rtccr1 = undefined, .rtccr2 = undefined,
            .rtcscr = undefined
        };
    }
    pub fn reset(self: *Rtc) void {
        // nope
    }

    pub fn write8 (self: *Rtc, off: usize, v: u8 ) void {
        std.debug.print("write8 RTC unknown 0x{x:} <- 0x{x:}\n", .{off,v});
        self.sys.sched.ibreak();
    }
    pub inline fn write16(self: *Rtc, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *Rtc, off: usize) u8  {
        std.debug.print("read8 RTC unknown 0x{x:}\n", .{off});
        self.sys.sched.ibreak();
        return 0;
    }
    pub inline fn read16(self: *Rtc, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

