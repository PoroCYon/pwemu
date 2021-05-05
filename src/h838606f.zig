
const std = @import("std");
const Allocator = std.mem.Allocator;

usingnamespace @import("sched.zig");

usingnamespace @import("h8300h.zig");
usingnamespace @import("h83860x/adc.zig");
usingnamespace @import("h83860x/aec.zig");
usingnamespace @import("h83860x/cmp.zig");
usingnamespace @import("h83860x/i2c.zig");
usingnamespace @import("h83860x/ioport.zig");
usingnamespace @import("h83860x/rtc.zig");
usingnamespace @import("h83860x/sci3.zig");
usingnamespace @import("h83860x/ssu.zig");
usingnamespace @import("h83860x/tmrb1.zig");
usingnamespace @import("h83860x/tmrw.zig");
usingnamespace @import("h83860x/wdt.zig");

usingnamespace @import("iface.zig");

pub const BusAccess = struct {
    cycle: bool = true,
    eff  : bool = true
};

pub const H838606F = struct {
    cycles: u64,
    sched: Sched,
    iface: Iface,
    ud: Iface_ud,

    h8300h: H8300H,

    // IO1
    rtc: Rtc,
    i2c: I2C,
    ioport: IOPort,
    tmrb1: TmrB1,
    cmp: Cmp,
    ssu: Ssu,
    tmrw: TmrW,

    flmcr1: u8, // reset on standby!
    flmcr2: u8,
    flpwr: u8,
    ebr1: u8, // reset on standby!
    fenr: u8,

    // IO2
    aec: Aec,
    sci3: Sci3, // +irda
    wdt: Wdt,
    adc: Adc,

    syscr1: u8,
    syscr2: u8,
    iegr: u8,
    ienr1: u8,
    ienr2: u8,
    osscr: u8,
    irr1: u8,
    irr2: u8,
    clkstpr1: u8,
    clkstpr2: u8,

    ram: *[2*1024]u8,
    flash: *[48*1024]u8,

    // TODO: callbacks for eeprom r/w, fn for accelerometer events,
    //       buzzer output callback, button input

    // TODO: version that just takes the ptr to own?
    pub fn init(ret: *H838606F, iface: Iface, ud: Iface_ud, alloc: *Allocator, allocgp: *Allocator, flashrom: *[48*1024]u8) !void {
        //var ret: H838606F = undefined;

        ret.iface = iface; ret.ud = ud;
        ret.h8300h = H8300H.init(ret);

        ret.sched = Sched.init(ret, allocgp);
        ret.rtc = Rtc.init(ret);
        ret.i2c = I2C.init(ret);
        ret.ioport = IOPort.init(ret);
        ret.tmrb1 = TmrB1.init(ret);
        ret.cmp = Cmp.init(ret);
        ret.ssu = Ssu.init(ret);
        ret.tmrw = TmrW.init(ret);
        ret.flmcr1 = 0; ret.flmcr2 = 0;
        ret.flpwr = 0; ret.ebr1 = 0; ret.fenr = 0;

        ret.aec = Aec.init(ret);
        ret.sci3 = Sci3.init(ret);
        ret.wdt = Wdt.init(ret);
        ret.adc = Adc.init(ret);
        ret.syscr1 = 0; ret.syscr2 = 0; ret.iegr = 0;
        ret.ienr1 = 0; ret.ienr2 = 0; ret.osscr = 0;
        ret.irr1 = 0; ret.irr2 = 0; ret.clkstpr1 = 0; ret.clkstpr2 = 0;

        ret.ram = @ptrCast(*[0x800]u8, try alloc.alloc(u8, 0x800));
        //std.mem.set([2*1024]u8, ret.ram, 0);
        //ret.flash = @ptrCast(*[48*1024]u8, try alloc.alloc(u8, 48*1024));
        //ret.load_rom(flashrom);
        ret.flash = flashrom;
    }

    pub fn load_rom(self: *H838606F, flashrom: *[48*1024]u8) void {
        ret.flash = flashrom;
        //for (flashrom[0..(48*1024)]) |b, i| self.flash[i] = b;
        //std.mem.copy([48*1024]u8, self.flash, flashrom);
    }

    pub fn reset(self: *H838606F) void {
        self.rtc.reset();
        self.i2c.reset();
        self.ioport.reset();
        self.tmrb1.reset();
        self.cmp.reset();
        self.ssu.reset();
        self.tmrw.reset();

        self.flmcr1 = 0; self.flmcr2 = 0;
        self.flpwr = 0; self.ebr1 = 0; self.fenr = 0;

        self.aec.reset();
        self.sci3.reset();
        self.wdt.reset();
        self.adc.reset();
        self.syscr1 = 0; self.syscr2 = 0; self.iegr = 0;
        self.ienr1 = 0; self.ienr2 = 0; self.osscr = 0;
        self.irr1 = 0; self.irr2 = 0; self.clkstpr1 = 0; self.clkstpr2 = 0;

        for (self.ram[0..(0x800)]) |_, i| self.ram[i] = 0;
        //std.mem.set([2*1024]u8, self.ram, 0);
    }

    pub fn run(self: *H838606F, inc: u64) void {
        self.sched.run(inc);
    }

    // TODO:
    // irda tx, rx
    // serial miso, mosi
    // serial chipsel / GPIO
    // button inputs
    // buzzer output
    // nmi
    //
    // port 8: rtc
    // port 9: timer, GPIO?
    // port B: serial, IRQ?
    // sci3/irda
    // aec
    // port 3: rx/tx, irq/gpio?
    // port 1: ROM stuff? GPIO?

    pub fn ioread8 (self: *H838606F, off: usize) u8  {
         // TODO
         return 0;
    }
    pub inline fn ioread16(self: *H838606F, off: usize) u16 {
        return (@as(u16, self.ioread8(off&0xfffe)) << 8)
             | (@as(u16, self.ioread8(off|0x0001)) << 0);
    }
    pub fn iowrite8 (self: *H838606F, off: usize, v: u8 ) void {
         // TODO
    }
    pub inline fn iowrite16(self: *H838606F, off: usize, v: u16) void {
         self.iowrite8(off&0xfffe, @truncate(u8, v >> 8));
         self.iowrite8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *H838606F, off: usize, comptime flags: BusAccess) u8  {
        if (off >= 0 and off < 48*1024) {
            if (flags.cycle) self.sched.cycle(2);
            return self.flash[off];
        } else if (off >= 0xf020 and off < 0xf100) {
            if (off >= 0xf020 and off <= 0xf02b) { // system regs
                if (flags.cycle) self.sched.cycle(2);
                return self.ioread8(off);
            } else if (off >= 0xf067 and off <= 0xf06f) { // rtc
                if (flags.cycle) self.sched.cycle(2);
                return self.rtc.read8(off);
            } else if (off >= 0xf078 and off <= 0xf07f) { // i2c
                if (flags.cycle) self.sched.cycle(2);
                return self.i2c.read8(off);
            } else if (off >= 0xf085 and off <= 0xf08c) { // ioport
                if (flags.cycle) self.sched.cycle(2);
                return self.ioport.read8(off);
            } else if (off >= 0xf0d0 and off <= 0xf0d1) { // tmrb1
                if (flags.cycle) self.sched.cycle(2);
                return self.tmrb1.read8(off);
            } else if (off >= 0xf0dc and off <= 0xf0de) { // cmp
                if (flags.cycle) self.sched.cycle(2);
                return self.cmp.read8(off);
            } else if (off >= 0xf0e0 and off <= 0xf0eb) { // ssu
                if (flags.cycle) self.sched.cycle(3); // !!!
                return self.ssu.read8(off);
            } else if (off >= 0xf0f0 and off <= 0xf0ff) { // tmrw
                if (flags.cycle) self.sched.cycle(2);
                return self.tmrw.read8(off);
            } else {
                std.debug.print("read8 unknown IO1 address 0x{x:}\n", .{off});
                self.sched.ibreak();
                return undefined;
            }
        } else if (off >= 0xf780 and off < 0xff80) {
            if (flags.cycle) self.sched.cycle(2);
            return self.ram[off - 0xf780];
        } else if (off >= 0xff80 and off <=0xffff) {
            if (off >= 0xff8c and off <= 0xff8f) { // aec
                if (flags.cycle) self.sched.cycle(2);
                return self.aec.read8(off);
            } else if (off == 0xff91) { // sci3
                if (flags.cycle) self.sched.cycle(2);
                return self.sci3.read8(off);
            } else if (off >= 0xff92 and off <= 0xff97) { // aec
                if (flags.cycle) self.sched.cycle(2);
                return self.aec.read8(off);
            } else if (off >= 0xff98 and off <= 0xffa7) { // sci3, irda
                if (flags.cycle) self.sched.cycle(3); // !!!
                return self.sci3.read8(off);
            } else if (off >= 0xffb0 and off <= 0xffb3) { // wdt
                if (flags.cycle) self.sched.cycle(2);
                return self.wdt.read8(off);
            } else if (off >= 0xffbc and off <= 0xffbf) { // adc
                if (flags.cycle) self.sched.cycle(2);
                return self.adc.read8(off);
            } else if (off >= 0xffc0 and off <= 0xffec) { // ioport
                if (flags.cycle) self.sched.cycle(2);
                return self.ioport.read8(off);
            } else if (off >= 0xfff0) { // system regs
                if (flags.cycle) self.sched.cycle(2);
                return self.ioread8(off);
            } else {
                std.debug.print("read8 unknown IO2 address 0x{x:}\n", .{off});
                self.sched.ibreak();
                return undefined;
            }
        } else {
            std.debug.print("read8 unknown WTF address 0x{x:}\n", .{off});
            self.sched.ibreak();
            return undefined;
        }
    }
    pub fn read16(self: *H838606F, off_: usize, comptime flags: BusAccess) u16 {
        const off = off_ ^ (off_ & 1); // address must be aligned

        if (off >= 0 and off < 48*1024) {
            // big-endian
            if (flags.cycle) self.sched.cycle(2);
            return (@as(u16, self.flash[off&0xfffe]) << 8)
                 |  @as(u16, self.flash[off|0x0001]);
        } else if (off >= 0xf020 and off < 0xf100) {
            if (off >= 0xf020 and off <= 0xf02b) { // system regs
                if (flags.cycle) self.sched.cycle(4);
                return self.ioread16(off);
            } else if (off >= 0xf067 and off <= 0xf06f) { // rtc
                if (flags.cycle) self.sched.cycle(4);
                return self.rtc.read16(off);
            } else if (off >= 0xf078 and off <= 0xf07f) { // i2c
                if (flags.cycle) self.sched.cycle(4);
                return self.i2c.read16(off);
            } else if (off >= 0xf085 and off <= 0xf08c) { // ioport
                if (flags.cycle) self.sched.cycle(4);
                return self.ioport.read16(off);
            } else if (off >= 0xf0d0 and off <= 0xf0d1) { // tmrb1
                if (flags.cycle) self.sched.cycle(4);
                return self.tmrb1.read16(off);
            } else if (off >= 0xf0dc and off <= 0xf0de) { // cmp
                if (flags.cycle) self.sched.cycle(4);
                return self.cmp.read16(off);
            } else if (off >= 0xf0e0 and off <= 0xf0eb) { // ssu
                if (flags.cycle) self.sched.cycle(6); // !!!
                return self.ssu.read16(off);
            } else if (off >= 0xf0f0 and off <= 0xf0ff) { // tmrw
                if (flags.cycle) self.sched.cycle(2); // 16-bit bus!
                return self.tmrw.read16(off);
            } else {
                std.debug.print("read16 unknown IO1 address 0x{x:}\n", .{off});
                self.sched.ibreak();
                return undefined;
            }
        } else if (off >= 0xf780 and off < 0xff80) {
            // big-endian
            if (flags.cycle) self.sched.cycle(2);
            return (@as(u16, self.ram[(off&0xfffe)-0xf780]) << 8)
                 |  @as(u16, self.ram[(off|0x0001)-0xf780]);
        } else if (off >= 0xff80 and off <=0xffff) {
            // timings aren't 100% accurate (8bit-bus accesses should be spread
            // up over multiple cycles, but, meh)
            if (off >= 0xff8c and off <= 0xff8f) { // aec
                if (flags.cycle) self.sched.cycle(2); // 16-bit bus!
                return self.aec.read16(off);
            } else if (off == 0xff91) { // sci3
                if (flags.cycle) self.sched.cycle(4);
                return self.sci3.read16(off);
            } else if (off >= 0xff92 and off <= 0xff97) { // aec
                if (flags.cycle) self.sched.cycle(4);
                return self.aec.read16(off);
            } else if (off >= 0xff98 and off <= 0xffa7) { // sci3, irda
                if (flags.cycle) self.sched.cycle(6); // !!!
                return self.sci3.read16(off);
            } else if (off >= 0xffb0 and off <= 0xffb3) { // wdt
                if (flags.cycle) self.sched.cycle(4);
                return self.wdt.read16(off);
            } else if (off >= 0xffbc and off <= 0xffbf) { // adc
                if (flags.cycle) {
                    if (off == 0xffbc or off == 0xffbd) {
                        self.sched.cycle(2);
                    } else { self.sched.cycle(4); }
                }
                return self.adc.read16(off);
            } else if (off >= 0xffc0 and off <= 0xffec) { // ioport
                if (flags.cycle) self.sched.cycle(4);
                return self.ioport.read16(off);
            } else if (off >= 0xfff0) { // system regs
                if (flags.cycle) self.sched.cycle(4);
                return self.ioread16(off);
            } else {
                std.debug.print("read16 unknown IO2 address 0x{x:}\n", .{off});
                self.sched.ibreak();
                return undefined;
            }
        } else {
            std.debug.print("read16 unknown WTF address 0x{x:}\n", .{off});
            self.sched.ibreak();
            return undefined;
        }
    }

    pub fn write8 (self: *H838606F, off: usize, v: u8 , comptime flags: BusAccess) void {
        if (off >= 0 and off < 48*1024) {
            //if (flags.cycle) self.sched.cycle(2);
            //self.flash[off] = v;
            std.debug.print("write8 flashrom 0x{x:} <- 0x{x:}\n", .{off,v});
            self.sched.ibreak();
        } else if (off >= 0xf020 and off < 0xf100) {
            if (off >= 0xf020 and off <= 0xf02b) { // system regs
                if (flags.cycle) self.sched.cycle(2);
                self.iowrite8(off, v);
            } else if (off >= 0xf067 and off <= 0xf06f) { // rtc
                if (flags.cycle) self.sched.cycle(2);
                self.rtc.write8(off, v);
            } else if (off >= 0xf078 and off <= 0xf07f) { // i2c
                if (flags.cycle) self.sched.cycle(2);
                self.i2c.write8(off, v);
            } else if (off >= 0xf085 and off <= 0xf08c) { // ioport
                if (flags.cycle) self.sched.cycle(2);
                self.ioport.write8(off, v);
            } else if (off >= 0xf0d0 and off <= 0xf0d1) { // tmrb1
                if (flags.cycle) self.sched.cycle(2);
                self.tmrb1.write8(off, v);
            } else if (off >= 0xf0dc and off <= 0xf0de) { // cmp
                if (flags.cycle) self.sched.cycle(2);
                self.cmp.write8(off, v);
            } else if (off >= 0xf0e0 and off <= 0xf0eb) { // ssu
                if (flags.cycle) self.sched.cycle(3); // !!!
                self.ssu.write8(off, v);
            } else if (off >= 0xf0f0 and off <= 0xf0ff) { // tmrw
                if (flags.cycle) self.sched.cycle(2);
                self.tmrw.write8(off, v);
            } else {
                std.debug.print("write8 unknown IO1 address 0x{x:} <- 0x{x:}\n", .{off,v});
                self.sched.ibreak();
            }
        } else if (off >= 0xf780 and off < 0xff80) {
            if (flags.cycle) self.sched.cycle(2);
            self.ram[off-0xf780] = v;
        } else if (off >= 0xff80 and off <=0xffff) {
            // IO2 TODO
            if (off >= 0xff8c and off <= 0xff8f) { // aec
                if (flags.cycle) self.sched.cycle(2);
                self.aec.write8(off, v);
            } else if (off == 0xff91) { // sci3
                if (flags.cycle) self.sched.cycle(2);
                self.sci3.write8(off, v);
            } else if (off >= 0xff92 and off <= 0xff97) { // aec
                if (flags.cycle) self.sched.cycle(2);
                self.aec.write8(off, v);
            } else if (off >= 0xff98 and off <= 0xffa7) { // sci3, irda
                if (flags.cycle) self.sched.cycle(3); // !!!
                self.sci3.write8(off, v);
            } else if (off >= 0xffb0 and off <= 0xffb3) { // wdt
                if (flags.cycle) self.sched.cycle(2);
                self.wdt.write8(off, v);
            } else if (off >= 0xffbc and off <= 0xffbf) { // adc
                if (flags.cycle) self.sched.cycle(2);
                self.adc.write8(off, v);
            } else if (off >= 0xffc0 and off <= 0xffec) { // ioport
                if (flags.cycle) self.sched.cycle(2);
                self.ioport.write8(off, v);
            } else if (off >= 0xfff0) { // system regs
                if (flags.cycle) self.sched.cycle(2);
                self.iowrite8(off, v);
            } else {
                std.debug.print("write8 unknown IO2 address 0x{x:} <- 0x{x:}\n", .{off,v});
                self.sched.ibreak();
            }
        } else {
            std.debug.print("write8 unknown WTF address 0x{x:} <- 0x{x:}\n", .{off,v});
            //self.sched.ibreak(); // written to on entry, ignore
        }
    }
    pub fn write16(self: *H838606F, off_: usize, v: u16, comptime flags: BusAccess) void {
        const off = off_ ^ (off_ & 1); // address must be aligned

        if (off >= 0 and off < 48*1024) {
            // big-endian
            //if (flags.cycle) self.sched.cycle(2);
            //self.flash[off&0xfffe] = @truncate(u8, v >> 8);
            //self.flash[off|0x0001] = @truncate(u8, v &255);
            std.debug.print("write16 flashrom 0x{x:} <- 0x{x:}\n", .{off,v});
            self.sched.ibreak();
        } else if (off >= 0xf020 and off < 0xf100) {
            if (off >= 0xf020 and off <= 0xf02b) { // system regs
                if (flags.cycle) self.sched.cycle(4);
                self.iowrite16(off, v);
            } else if (off >= 0xf067 and off <= 0xf06f) { // rtc
                if (flags.cycle) self.sched.cycle(4);
                self.rtc.write16(off, v);
            } else if (off >= 0xf078 and off <= 0xf07f) { // i2c
                if (flags.cycle) self.sched.cycle(4);
                self.i2c.write16(off, v);
            } else if (off >= 0xf085 and off <= 0xf08c) { // ioport
                if (flags.cycle) self.sched.cycle(4);
                self.ioport.write16(off, v);
            } else if (off >= 0xf0d0 and off <= 0xf0d1) { // tmrb1
                if (flags.cycle) self.sched.cycle(4);
                self.tmrb1.write16(off, v);
            } else if (off >= 0xf0dc and off <= 0xf0de) { // cmp
                if (flags.cycle) self.sched.cycle(4);
                self.cmp.write16(off, v);
            } else if (off >= 0xf0e0 and off <= 0xf0eb) { // ssu
                if (flags.cycle) self.sched.cycle(6); // !!!
                self.ssu.write16(off, v);
            } else if (off >= 0xf0f0 and off <= 0xf0ff) { // tmrw
                if (flags.cycle) self.sched.cycle(2); // 16-bit bus!
                self.tmrw.write16(off, v);
            } else {
                std.debug.print("write16 unknown IO1 address 0x{x:} <- 0x{x:}\n", .{off,v});
                self.sched.ibreak();
            }
        } else if (off >= 0xf780 and off < 0xff80) {
            // big-endian
            if (flags.cycle) self.sched.cycle(2);
            self.ram[(off&0xfffe)-0xf780] = @truncate(u8, v >> 8);
            self.ram[(off|0x0001)-0xf780] = @truncate(u8, v &255);
        } else if (off >= 0xff80 and off <=0xffff) {
            if (off >= 0xff8c and off <= 0xff8f) { // aec
                if (flags.cycle) self.sched.cycle(2); // 16-bit bus!
                self.aec.write16(off, v);
            } else if (off == 0xff91) { // sci3
                if (flags.cycle) self.sched.cycle(4);
                self.sci3.write16(off, v);
            } else if (off >= 0xff92 and off <= 0xff97) { // aec
                if (flags.cycle) self.sched.cycle(4);
                self.aec.write16(off, v);
            } else if (off >= 0xff98 and off <= 0xffa7) { // sci3, irda
                if (flags.cycle) self.sched.cycle(6); // !!!
                self.sci3.write16(off, v);
            } else if (off >= 0xffb0 and off <= 0xffb3) { // wdt
                if (flags.cycle) self.sched.cycle(4);
                self.wdt.write16(off, v);
            } else if (off >= 0xffbc and off <= 0xffbf) { // adc
                if (flags.cycle) {
                    if (off == 0xffbc or off == 0xffbd) {
                        self.sched.cycle(2);
                    } else { self.sched.cycle(4); }
                }
                self.adc.write16(off, v);
            } else if (off >= 0xffc0 and off <= 0xffec) { // ioport
                if (flags.cycle) self.sched.cycle(4);
                self.ioport.write16(off, v);
            } else if (off >= 0xfff0) { // system regs
                if (flags.cycle) self.sched.cycle(4);
                self.iowrite16(off, v);
            } else {
                std.debug.print("write16 unknown IO2 address 0x{x:} <- 0x{x:}\n", .{off,v});
                self.sched.ibreak();
            }
        } else {
            std.debug.print("write16 unknown WTF address 0x{x:} <- 0x{x:}\n", .{off,v});
            self.sched.ibreak();
        }
    }
};

// mmap:
// 0000..0004f: interrupt vector
// 0050..bfff: flash ROM
// c000..f01f: unused
// f020..f0ff: IO 1
// f100..f77f: unused
// f780..ff7f: RAM (2k)
// ff80..ffff: IO 2

// flash ROM:
// * erasing unit: 1k x4 / 28k / 16k
// * programming unit: 128b
// EBR1:
// bit 0: if 1: 1k 0000..03ff erased
// bit 1:          0400..07ff
// bit 2:          0800..0bff
// bit 3:          0c00..0fff
// bit 4:      28k 1000..7fff
// bit 5:      16k 8000..bfff
//
// clock: 4 or 10 MHz? system or flash clock??
// * system clock: 4.194304 MHz?
// modes:
// * active, high-speed: cpu/sys clk == ph_osc
// * active, med-speed: cpu clk == ph_osc / freqdiv (8,16,32,64)
// * subactive: cpu clk == ph_w / 1,2,4,8; ph_w == external (38.4 kHz or 32768 Hz)
// * sleep hispeed: CPU halted, cpuclk == ph_osc
// * sleep medspeed: cpu halted, cpuclk == ph_osc / freqdiv
// * subsleep: cpu halted, cpuclk == ph_w/...
// * watch: same
// * standby: cpu & periph halted
// + standby separate modules
//
// evt:
// 0000: reset: from startup or wdt: set ccr.i to 1, read 0000,0001, jmp to that addr
// 0002..000c: reserved
// 000e: nmi
// 0010..0016: trap 0..3
// 0018: reserved
// 001a: sleep (awake from?)
// 001c..001e: reserved
// 0020..0022: irq0..1
// 0024: irqaec
// 0026..0028: reserved
// 002a..002c: comp0..1
// 002e..003c: rtc 0.25s, 0.5s, 1s, 1m, 1h, 1d, 1w, * overflows
// 003e: wdt ovf
// 0040: async event counter ovf
// 0042: timer b1 ovf
// 0044: ssu/i2c irq
// 0046: timer w ovf
// 0048: reserved
// 004a: sci3 irq
// 004c: adc finished
// 004e: reserved
//
// IO map:
// IO 1 (f020): 8bit access=2states
//  FLASHROM:
//   020: FLMCR1: ctl 1
//   021: FLMCR2: ctl 2
//   022: FLPWCR: pwctl
//   023: EBR1: erase block reg
//   02b: FENR: flashmem enable
//  RTC:
//   067: RTCFLG: irq flag (uninited at startup)
//   068: FSECDR: second/free-running data (uninited at startup)
//   069: FMINDR: minute (uninited at startup)
//   06a: FHRDR: hour (uninited at startup)
//   06b: RWKDR: day of week (uninited at startup)
//   06c: RTCCR1: cr1 (uninited at startup)
//   06d: RTCCR2 (uninited at startup)
//   06f: RTCSCR: clk source
//  I2C:
//   078: ICCR1: cr1
//   079: ICCR2
//   07a: ICMR: bus mode
//   07b: ICIER: irqen
//   07c: ICSR: status
//   07d: SAR: slave addr
//   07e: ICDRT: send data
//   07f: ICDRR: recv data
//  system:
//   085: PFCR: port fn ctl
//  IOport:
//   086: PUCR8: pullup ctl 8
//   087: PUCR9
//   08c: PODR9: opendrain ctl 9
//  timer B1:
//   0d0: TMB1: mode
//   0d1: TCB1/TLB1: R/W: counter/load
//  comparator:
//   0dc: CMCR0: cr0
//   0dd: CMCR1
//   0de: CMDR: data
//  ssu: (access=3 states!)
//   0e0: SSCRH: cr hi
//   0e1: SSCRL: cr lo
//   0e2: SSMR: mode
//   0e3: SSER: enable
//   0e4: SSSR: status
//   0e9: SSRDR: recv
//   0eb: SSTDR: send
//  timer w:
//   0f0: TMRW: mode
//   0f1: TCRW: ctl
//   0f2: TIERW: irqen
//   0f3: TSRW: status
//   0f4: TIOR0: ioctl
//   0f5: TIOR1
//   0f6: TCNT: counter
//   0f8: GRA: general reg A (16bit)
//   0fa: GRB
//   0fc: GRC
//   0fe: GRD
//
// IO 2 (ff80): 8/16bit access=2states
//  aec (16bit!):
//   8c: ECPWCR: counter pwm compare
//   8e: ECPWDR: counter pwm data
//  sci3:
//   91: SPCR: serial port ctl
//  aec:
//   92: AEGSR: input pin edgesel
//   94: ECCR: event cnt ctl
//   95: ECCSR: ^^ ctl/stat
//   96: ECH: event cnt hi
//   97: ECL: event cnt lo
//  sci3:
//   98: SMR3: serial mode
//   99: BRR3: bitrate
//   9a: SCR3: serial ctl
//   9b: TDR3: send data
//   9c: SSR3: serial status
//   9d: RDR3: recv data
//   a6: SEMR: serial ext mode
//  irda:
//   a7: IrCR: irda ctl
//  wdt:
//   b0: TMWD: timer mode
//   b1: TCSRWD1: ctl/stat
//   b2: TCSRWD2
//   b3: TCWD: counter
//  adc:
//   bc: ADRR: result (16bit!) (uninited at startup)
//   be: AMR: mode
//   bf: ADSR: start
//  ioport:
//   c0: PMR1: mode 1
//   c2: PMR3
//   ca: PMRB
//   d4: PDR1: data
//   d6: PDR3
//   db: PDR8
//   dc: PDR9
//   de: PDRB
//   e0: PUCR1: pullup ctl
//   e1: PUCR3
//   e4: PCR1: cr
//   e6: PCR3: e6
//   eb: PCR8
//   ec: PCR9
//  system:
//   f0: SYSCR1
//   f1: SYSCR2
//  interrupt:
//   f2: IEGR: edgesel
//   f3: IENR1: enable
//   f4: IENR2
//  system:
//   f5: OSCCR: osc ctl
//  interrupt:
//   f6: IRR1: flag
//   f7: IRR2
//  system:
//   fa: CLKSTPR1: clk stop
//   fb: CLKSTPR2

//write8 TMRW unknown 0xf0f1 <- 0xc0
//B! pc=0x36d0 fetched=0xf010 ccr=----n--- state=State.exec pending=PendingExn.none
//er0=0x    c000 er1=0x       8 er2=0xaaaaaaaa er3=0xaaaaaaaa
//er4=0xaaaaaaaa er5=0xaaaaaaaa er6=0xaaaaf7be er7=0xaaaaff7a

