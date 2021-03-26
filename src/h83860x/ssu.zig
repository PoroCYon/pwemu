
const H838606F = @import("../h838606f.zig").H838606F;

pub const Ssu = extern struct { // IO1
    sys: *H838606F,

    sscr: u16,
    ssmr: u8,
    sser: u8,
    sssr: u8,
    ssrdr: u8,
    sstdr: u8,

    pub fn init(s: *H838606F) Ssu {
        return Ssu { .sys = s,
            .sscr = 0, .ssmr = 0, .sser = 0, .sssr = 0, .ssrdr = 0,
            .sstdr = 0 };
    }
    pub fn reset(self: *Ssu) void {
        self.sscr = 0;
        self.ssmr = 0;
        self.sser = 0;
        self.sssr = 0;
        self.ssrdr = 0;
        self.sstdr = 0;
    }

    pub fn write8 (self: *Ssu, off: usize, v: u8 ) void { }
    pub fn write16(self: *Ssu, off: usize, v: u16) void { }

    pub fn read8 (self: *Ssu, off: usize) u8  { return 0; }
    pub fn read16(self: *Ssu, off: usize) u16 { return 0; }
};

