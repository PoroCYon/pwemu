
const H838606F = @import("h838606f.zig").H838606F;

pub const TmrB1 = extern struct { // IO1
    sys: *H838606F,

    tmb1: u8,
    tcb1: u8,
    tlb1: u8,

    pub fn init(s: *H838606F) TmrB1 {
        return TmrB1 { .sys = s, .tmb1 = 0, .tcb1 = 0, .tlb1 = 0 };
    }
    pub fn reset(self: *TmrB1) void {
        self.tmb1 = 0;
        self.tcb1 = 0;
        self.tlb1 = 0;
    }

    pub fn write8 (self: *TmrB1, off: usize, v: u8 ) void { }
    inline fn write16(self: *TmrB1, off: usize, v: u16) void {
        write8(self, off+0, (v >> 8) & 0xff);
        write8(self, off+1, (v >> 0) & 0xff);
    }

    pub fn read8 (self: *TmrB1, off: usize) u8  { return 0; }
    inline fn read16(self: *TmrB1, off: usize) u16 {
        return (@as(u16, read8(cmp, off+0)) << 8)
             | (@as(u16, read8(cmp, off+1)) << 0);
    }
};

