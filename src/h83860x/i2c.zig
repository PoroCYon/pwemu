
const H838606F = @import("../h838606f.zig").H838606F;

pub const I2C = extern struct { // IO1
    sys: *H838606F,

    iccr1: u8,
    iccr2: u8,
    icmr: u8,
    icier: u8,
    icsr: u8,
    sar: u8,
    icdrt: u8,
    icdrr: u8,

    pub fn init(s: *H838606F) I2C {
        return I2C { .sys = s,
                     .iccr1 = 0, .iccr2 = 0, .icmr = 0, .icier = 0,
                     .icsr = 0, .sar = 0, .icdrt = 0, .icdrr = 0 };
    }
    pub fn reset(self: *I2C) void {
        self.iccr1 = 0;
        self.iccr2 = 0;
        self.icmr = 0;
        self.icier = 0;
        self.icsr = 0;
        self.sar = 0;
        self.icdrt = 0;
        self.icdrr = 0;
    }

    pub fn write8 (self: *I2C, off: usize, v: u8 ) void { }
    pub inline fn write16(self: *I2C, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off&0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *I2C, off: usize) u8  { return 0; }
    pub inline fn read16(self: *I2C, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

