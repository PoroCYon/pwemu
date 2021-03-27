
const H838606F = @import("../h838606f.zig").H838606F;

pub const Cmp = struct { // IO1
    sys: *H838606F,

    cmcr0: u8,
    cmcr1: u8,
    cmdr: u8,

    pub fn init(s: *H838606F) Cmp {
        return Cmp { .sys = s, .cmcr0 = 0, .cmcr1 = 0, .cmdr = 0 };
    }
    pub fn reset(self: *Cmp) void {
        self.cmcr0 = 0;
        self.cmcr1 = 0;
        self.cmdr = 0;
    }

    pub fn write8 (self: *Cmp, off: usize, v: u8 ) void { }
    pub inline fn write16(self: *Cmp, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *Cmp, off: usize) u8  { return 0; }
    pub inline fn read16(self: *Cmp, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

