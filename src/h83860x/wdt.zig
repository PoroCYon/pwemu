
const H838606F = @import("../h838606f.zig").H838606F;

pub const Wdt = extern struct { // IO2
    sys: *H838606F,

    tmwd: u8,
    tcsrwd1: u8,
    tcsrwd2: u8,
    tcwd: u8,

    pub fn init(s: *H838606F) Wdt {
        return Wdt { .sys = s, .tmwd = 0, .tcsrwd1 = 0, .tcsrwd2 = 0, .tcwd = 0 };
    }
    pub fn reset(self: *Wdt) void {
        self.tmwd = 0;
        self.tcsrwd1 = 0;
        self.tcsrwd2 = 0;
        self.tcwd = 0;
    }

    pub fn write8 (self: *Wdt, off: usize, v: u8 ) void { }
    inline fn write16(self: *Wdt, off: usize, v: u16) void {
        write8(self, off+0, (v >> 8) & 0xff);
        write8(self, off+1, (v >> 0) & 0xff);
    }

    pub fn read8 (self: *Wdt, off: usize) u8  { return 0; }
    inline fn read16(self: *Wdt, off: usize) u16 {
        return (@as(u16, read8(cmp, off+0)) << 8)
             | (@as(u16, read8(cmp, off+1)) << 0);
    }
};

