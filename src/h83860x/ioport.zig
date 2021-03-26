
const H838606F = @import("../h838606f.zig").H838606F;

pub const IOPort = extern struct {
    sys: *H838606F,

    // IO1
    pucr8: u8,
    pucr9: u8,
    podr9: u8,

    // IO2
    pmr1: u8,
    pmr3: u8,
    pmrb: u8,
    pdr1: u8,
    pdr3: u8,
    pdr8: u8,
    pdr9: u8,
    pucr1: u8,
    pucr3: u8,
    pcr1: u8,
    pcr3: u8,
    pcr8: u8,
    pcr9: u8,

    pub fn init(s: *H838606F) IOPort {
        return IOPort { .pucr8 = 0, .pucr9 = 0, .podr9 = 0,
            .pmr1 = 0, .pmr3 = 0, .pmrb = 0,
            .pdr1 = 0, .pdr3 = 0, .pdr8 = 0, .pdr9 = 0,
            .pucr1 = 0, .pucr3 = 0,
            .pcr1 = 0, .pcr3 = 0, .pcr8 = 0, .pcr9 = 0,
            .sys = s,
        };
    }
    pub fn reset(self: *IOPort) void {
        self.pucr8 = 0;
        self.pucr9 = 0;
        self.podr9 = 0;

        self.pmr1 = 0;
        self.pmr3 = 0;
        self.pmrb = 0;

        self.pdr1 = 0;
        self.pdr3 = 0;
        self.pdr8 = 0;
        self.pdr9 = 0;

        self.pucr1 = 0;
        self.pucr3 = 0;

        self.pcr1 = 0;
        self.pcr3 = 0;
        self.pcr8 = 0;
        self.pcr9 = 0;
    }

    pub fn write8 (self: *IOPort, off: usize, v: u8 ) void { }
    inline fn write16(self: *IOPort, off: usize, v: u16) void {
        write8(self, off+0, (v >> 8) & 0xff);
        write8(self, off+1, (v >> 0) & 0xff);
    }

    pub fn read8 (self: *IOPort, off: usize) u8  { return 0; }
    inline fn read16(self: *IOPort, off: usize) u16 {
        return (@as(u16, read8(cmp, off+0)) << 8)
             | (@as(u16, read8(cmp, off+1)) << 0);
    }
};

