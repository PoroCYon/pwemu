
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;
const Event_ud = @import("../sched.zig").Event_ud;

pub const Wdt = struct { // IO2
    sys: *H838606F,

    evid: u64,
    start: u64,

    tmwd: u4, // clksel
    tcsrwd1: u8,
    tcsrwd2: u8,
    tcwd: u8, // counter

    fn mwd2clks(self: *Wdt) u64 {
        return switch (self.tmwd) {
            0x0,0x1,0x2,0x3 => 2048, // Rosc
            0x4 => 16, // phi_w
            0x5 => 256, // phi_w
            0x8 => 64, // phi
            0x9 => 128,
            0xa => 256,
            0xb => 512,
            0xc => 1024,
            0xd => 2048,
            0xe => 4096,
            0xf => 8192,
            0b0110,0b0111 => unreachable
        };
    }

    fn tcwd_cur(self: *Wdt) u64 {
        return @divExact((self.sys.sched.cycles - self.start), self.mwd2clks());
    }
    fn on_ovf(sys: *H838606F, self_: Event_ud) void {
        const self = @ptrCast(*Wdt, self_);

        self.evid = 0;

        if (self.tcsrwd1 & 0x04 == 0) return; // wdt is off

        self.sys.sched.ibreak();

        self.tcsrwd2 |= 0x80;
        if (self.tcsrwd2 & 0x20 == 0) {
            // reset the entire system on overflow
            std.debug.print("WDT overflow! => RST\n", .{});
            self.sys.reset(); // will call sched_ovf(), resets tcsrwd2 bit 7... (intended!)
            self.tcsrwd1 |= 0x01;
        } else {
            std.debug.print("WDT overflow! => IRQ\n", .{});
            if ((self.tcsrwd2 & 0x08) != 0) {
                self.tcsrwd1 |= 0x01;
                self.sys.h8300h.raise(.wdt);
            }

            self.tcwd = 0;
            self.start = self.sys.sched.cycles;
            self.sched_ovf();
        }
    }
    fn sched_ovf(self: *Wdt) void {
        if (self.evid != 0) self.sys.sched.cancel_ev(self.evid);

        const cycInFuture = (0x100 - @as(u64,self.tcwd)) * self.mwd2clks();
        self.evid = self.sys.sched.enqueue(cycInFuture, on_ovf, @ptrCast(Event_ud, self));
    }

    pub fn init(s: *H838606F) Wdt {
        return Wdt { .sys = s, .start = 0, .evid = 0,
            .tmwd = 0, .tcsrwd1 = 0, .tcsrwd2 = 0, .tcwd = 0 };
    }
    pub fn reset(self: *Wdt) void {
        self.start = self.sys.sched.cycles;

        self.tmwd = 0;
        self.tcsrwd1 = 0x04; // wdt defaults to on
        self.tcsrwd2 = 0;
        self.tcwd = 0;

        if (self.evid != 0) self.sys.sched.cancel_ev(self.evid);
        self.evid = 0;

        self.sched_ovf();
    }

    pub fn write8 (self: *Wdt, off: usize, v: u8 ) void {
        std.debug.print("WDT_TCSRWD1 write!\n", .{});

        switch (off) {
            0xffb0 => {
                const vv = v & 0xe;
                if (vv == 0b0110) {
                    std.debug.print("TMWD invalid clksel 0b011x\n", .{});
                    self.sys.sched.ibreak();
                }
                if ((vv == 0b0100 or (v&0xc) == 0b0000) and (self.tcsrwd2 & 0x20) != 0) {
                    std.debug.print("TMWD invalid clksel 0b010x or 0b00xx: can't select when using interval timer mode\n", .{});
                    self.sys.sched.ibreak();
                }

                self.tmwd = @truncate(u4,v);

                // reschedule
                self.tcwd = @truncate(u8,self.tcwd_cur());
                self.start = self.sys.sched.cycles;
                if (self.evid != 0) self.sys.sched.cancel_ev(self.evid);
                self.evid = 0;
                if ((self.tcsrwd1 & (1<<2)) != 0) { // WDON
                    self.sched_ovf();
                }
            }, 0xffb1 => {
                var vv = v;
                // 0x40: tcwd write enable
                // 0x10: wdon/wrst enable
                // 0x04: wdon: enables wdt
                // 0x01: wrst: wdt has caused a reset before
                if ((vv & 0x80) != 0)
                    vv = (vv&~@as(u8,0x40)) | (self.tcsrwd1 & 0x40);
                if ((vv & 0x20) != 0)
                    vv = (vv&~@as(u8,0x10)) | (self.tcsrwd1 & 0x10);
                if ((vv & 0x08) != 0 or (vv & 0x10) == 0)
                    vv = (vv&~@as(u8,0x04)) | (self.tcsrwd1 & 0x04);
                if ((vv & 0x02) != 0 or (vv & 0x10) == 0)
                    vv = (vv&~@as(u8,0x01)) | (self.tcsrwd1 & 0x01);

                // set WRON to 0
                if ((v & 0x02) == 0 and (v & 0x10) != 0 and (v & 0x04) == 0) {
                    if (self.evid != 0) self.sys.sched.cancel_ev(self.evid);
                    self.evid = 0;
                }

                self.tcsrwd1 = vv;
            }, 0xffb2 => {
                var vvv = v;
                // 0x80: tcwd has overflown
                // 0x20: 0=wdt(==cause rst) 1=interval timer(==gen irq)
                // 0x08: irqen on overflow
                if ((vvv & 0x40) != 0)
                    vvv = (vvv&~@as(u8,0x20)) | (self.tcsrwd2 & 0x20);
                if ((vvv & 0x10) != 0)
                    vvv = (vvv&~@as(u8,0x08)) | (self.tcsrwd2 & 0x08);

                const vv = self.tmwd;
                if ((vv == 0b0100 or (vv&0xc) == 0b0000) and (vvv & 0x20) != 0) {
                    std.debug.print("TCSRWD2: can't select interval timer mode when TMWD clksel is 0b010x or 0b00xx\n", .{});
                    self.sys.sched.ibreak();
                }

                self.tcsrwd2 = vvv;
            }, 0xffb3 => {
                if ((self.tcsrwd1 & (1<<6)) != 0) {
                    self.tcwd = v;
                    self.start = self.sys.sched.cycles;
                    if ((self.tcsrwd1 & (1<<2)) != 0) { // WDON
                        self.sched_ovf();
                    }
                }
            }, else => {
                std.debug.print("write8 WDT unknown 0x{x:}\n", .{off});
                self.sys.sched.ibreak();
            }
        }
    }
    pub inline fn write16(self: *Wdt, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *Wdt, off: usize) u8  {
        return switch (off) {
            0xffb0 => @as(u8,self.tmwd) | 0xf0,
            0xffb1 => blk: {
                const v = self.tcsrwd1 | 0x80|0x20|0x08|0x02;
                std.debug.print("read8 TCSRWD1 = 0x{x:}\n", .{v});
                break :blk v;
            },
            0xffb2 => blk: {
                const v = self.tcsrwd2 | 7;
                if ((v & 0x80) != 0) self.tcsrwd2 ^= 0x80;
                break :blk v;
            },
            0xffb3 => @truncate(u8, self.tcwd_cur()),//self.tcwd,
            else => blk: {
                std.debug.print("read8 WDT unknown 0x{x:}\n", .{off});
                self.sys.sched.ibreak();
                break :blk 0;
            }
        };
    }
    pub inline fn read16(self: *Wdt, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

