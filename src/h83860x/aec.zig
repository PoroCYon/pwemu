
const H838606F = @import("../h838606f.zig").H838606F;

pub const Aec = extern struct { // IO2
    sys: *H838606F,

    ecpwcr: u16,
    ecpwdr: u16,

    aegsr: u8,
    eccr: u8,
    eccsr: u8,
    ec: u16,

    pub fn init(s: *H838606F) Aec {
        return Aec { .sys = s, .ecpwcr = 0, .ecpwdr = 0,
                     .aegsr = 0, .eccr = 0, .eccsr = 0, .ec = 0 };
    }
    pub fn reset(self: *Aec) void {
        self.ecpwcr = 0;
        self.ecpwdr = 0;

        self.aegsr = 0;
        self.eccr = 0;
        self.eccsr = 0;
        self.ec = 0;
    }

    pub fn write8 (self: *Aec, off: usize, v: u8 ) void { }
    pub inline fn write16(self: *Aec, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *Aec, off: usize) u8  { return 0; }
    pub inline fn read16(self: *Aec, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

