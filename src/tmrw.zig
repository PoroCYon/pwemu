
const H838606F = @import("h838606f.zig").H838606F;

pub const TmrW = extern struct { // IO1
    sys: *H838606F,

    tmrw: u8,
    tcrw: u8,
    tierw: u8,
    tsrw: u8,
    tior0: u8,
    tior1: u8,
    tcnt: u16,
    gra: u16, grb: u16, grc: u16, grd: u16,

    pub fn init(s: *H838606F) TmrW {
        return TmrW { .sys = s,
            .tmrw = 0, .tcrw = 0, .tierw = 0, .tsrw = 0,
            .tior0 = 0, .tior1 = 0, .tcnt = 0,
            .gra = 0, .grb = 0, .grc = 0, .grd = 0 };
    }
    pub fn reset(self: *TmrW) void {
        self.tmrw = 0;
        self.tcrw = 0;
        self.tierw = 0;
        self.tsrw = 0;
        self.tior0 = 0;
        self.tior1 = 0;
        self.tcnt = 0;
        self.gra = 0;
        self.grb = 0;
        self.grc = 0;
        self.grd = 0;
    }

    pub fn write8 (self: *TmrW, off: usize, v: u8 ) void { }
    pub fn write16(self: *TmrW, off: usize, v: u16) void { }

    pub fn read8 (self: *TmrW, off: usize) u8  { return 0; }
    pub fn read16(self: *TmrW, off: usize) u16 { return 0; }
};

