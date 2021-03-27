
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;

pub const Ssu = struct { // IO1
    sys: *H838606F,

    sscrh: u8,
    sscrl: u4, // bit 6..3
    ssmr: u8, // bit 4,3 unused // has interesting bits that should be iplemented
    sser: u8, // bit 4 unused
    sssr: u7, // bit 5,4 unused
    ssrdr: u8,
    sstdr: u8,

    // TODO: interrupts
    // TODO: right now, transfers happen instantly, this should be
    //       reworked so that it happens the way it does on real hw.
    //       the H8/3060x PDF has all the relevant timing diagrams

    pub fn init(s: *H838606F) Ssu {
        return Ssu { .sys = s,
            .sscrh = 0, .sscrl = 0, .ssmr = 0, .sser = 0, .sssr = 0,
            .ssrdr = 0, .sstdr = 0 };
    }
    pub fn reset(self: *Ssu) void {
        self.sscrh = 0;
        self.sscrl = 0;
        self.ssmr = 0;
        self.sser = 0;
        self.sssr = 0;
        self.ssrdr = 0;
        self.sstdr = 0;
    }

    pub fn write8 (self: *Ssu, off: usize, v: u8 ) void {
        //std.debug.print("SSU write8 0x{x:} <- 0x{x:}\n", .{off,v});

        switch (off) {
            0xf0e0 => { // SSCRH
                // only modify bit 4 when bit 3 is set
                if (v & (1<<3) != 0) {
                    self.sscrh = v & ~@as(u8,1<<3);
                } else self.sscrh = (v & ~@as(u8,1<<4)) | (self.sscrh & (1<<4));
                // TODO: port stuff w/ bit2..0
            },
            0xf0e1 => {
                self.sscrl = @truncate(u4, v>>3);

                if (v & (1<<5) != 0) {
                    // TODO: reset stuff? (xfer shift regs etc., when implemented)
                }
            },
            0xf0e2 => self.ssmr = v & ~@as(u8,0x18),
            0xf0e3 => self.sser = v & ~@as(u8,0x10),
            0xf0e4 => self.sssr = self.sssr & @truncate(u7, v & ~@as(u8,0x30)),
            0xf0e9 => { }, // SSRDR is readonly
            0xf0eb => {
                self.sstdr = v;
                if (self.sser & (1<<7) != 0)
                    self.sys.iface.serial_write(self.sys.ud, v);
            },
            else => {
                std.debug.print("write8 unknown SSU address 0x{x:} <- 0x{x:}\n", .{off,v});
                self.sys.sched.ibreak();
            }
        }
    }
    pub inline fn write16(self: *Ssu, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *Ssu, off: usize) u8  {
        return switch (off) {
            0xf0e0 => self.sscrh,
            0xf0e1 => @as(u8,self.sscrl << 3),
            0xf0e2 => self.ssmr,
            0xf0e3 => self.sser,
            0xf0e4 => @as(u8,self.sssr) | 2|4|8, // hardcode: can always send and recv
            0xf0e9 => blk: {//self.ssrdr,
                if (self.sser & (1<<6) != 0) {
                    break :blk self.sys.iface.serial_read(self.sys.ud);
                } else break :blk self.ssrdr;
            },
            0xf0eb => self.sstdr,
            else => blk: {
                std.debug.print("read8 unknown SSU address 0x{x:}\n", .{off});
                self.sys.sched.ibreak();
                break :blk undefined;
            }
        };
    }
    pub inline fn read16(self: *Ssu, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

