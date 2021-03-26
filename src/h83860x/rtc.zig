
const H838606F = @import("../h838606f.zig").H838606F;

pub const Rtc = extern struct { // IO1
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

    pub fn write8 (self: *Rtc, off: usize, v: u8 ) void { }
    inline fn write16(self: *Rtc, off: usize, v: u16) void {
        write8(self, off+0, (v >> 8) & 0xff);
        write8(self, off+1, (v >> 0) & 0xff);
    }

    pub fn read8 (self: *Rtc, off: usize) u8  { return 0; }
    inline fn read16(self: *Rtc, off: usize) u16 {
        return (@as(u16, read8(cmp, off+0)) << 8)
             | (@as(u16, read8(cmp, off+1)) << 0);
    }
};

