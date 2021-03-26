
const H838606F = @import("../h838606f.zig").H838606F;

pub const Sci3 = extern struct { // IO2
    sys: *H838606F,

    spcr: u8,
    smr3: u8,
    brr3: u8,
    scr3: u8,
    tdr3: u8,
    ssr3: u8,
    rdr3: u8,
    semr: u8,

    ircr: u8,

    // NOTE: access is 3 states instead of 2! EXCEPT for IrCR!!!!

    pub fn init(s: *H838606F) Sci3 {
        return Sci3 { .sys = s,
            .spcr = 0, .smr3 = 0, .brr3 = 0, .scr3 = 0,
            .tdr3 = 0, .ssr3 = 0, .rdr3 = 0, .semr = 0, .ircr = 0
        };
    }

    // NOTE: should also be called on watch or standby!
    pub fn reset(self: *Sci3) void {
        self.spcr = 0;
        self.smr3 = 0;
        self.brr3 = 0;
        self.scr3 = 0;
        self.tdr3 = 0;
        self.ssr3 = 0;
        self.rdr3 = 0;
        self.semr = 0;
    }

    pub fn write8 (self: *Sci3, off: usize, v: u8 ) void { }
    pub inline fn write16(self: *Sci3, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *Sci3, off: usize) u8  { return 0; }
    pub inline fn read16(self: *Sci3, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

