
const H838606F = @import("h838606f.zig").H838606F;

pub const Adc = extern struct { // IO2
    sys: *H838606F,

    adrr: u16, // don't init this on reset!
    amr: u8,
    adsr: u8,

    pub fn init(s: *H838606F) Adc {
        return Adc { .sys = s, .adrr = undefined, .amr = 0, .adsr = 0 };
    }
    pub fn reset(self: *Adc) void {
        self.amr = 0;
        self.adsr = 0;
    }

    pub fn write8 (self: *Adc, off: usize, v: u8 ) void { }
    pub fn write16(self: *Adc, off: usize, v: u16) void { }

    pub fn read8 (self: *Adc, off: usize) u8  { return 0; }
    pub fn read16(self: *Adc, off: usize) u16 { return 0; }
};

