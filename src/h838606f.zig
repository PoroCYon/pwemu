
const std = @import("std");
const Allocator = std.mem.Allocator;

usingnamespace @import("sched.zig");

usingnamespace @import("h8300h.zig");
usingnamespace @import("adc.zig");
usingnamespace @import("aec.zig");
usingnamespace @import("cmp.zig");
usingnamespace @import("i2c.zig");
usingnamespace @import("ioport.zig");
usingnamespace @import("rtc.zig");
usingnamespace @import("sci3.zig");
usingnamespace @import("ssu.zig");
usingnamespace @import("tmrb1.zig");
usingnamespace @import("tmrw.zig");
usingnamespace @import("wdt.zig");

pub const BusAccess = struct {
    cycle: bool = true,
    eff  : bool = true
};

pub const H838606F = struct {
    cycles: u64,
    sched: Sched,

    h8300h: H8300H,

    // IO1
    rtc: Rtc,
    i2c: I2C,
    ioport: IOPort,
    tmrb1: TmrB1,
    cmp: Cmp,
    ssu: Ssu,
    tmrw: TmrW,

    pfcr: u8,
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
    pub fn init(ret: *H838606F, alloc: *Allocator, allocgp: *Allocator, flashrom: *[48*1024]u8) !void {
        //var ret: H838606F = undefined;

        ret.h8300h = H8300H.init(ret);

        ret.sched = Sched.init(ret, allocgp);
        ret.rtc = Rtc.init(ret);
        ret.i2c = I2C.init(ret);
        ret.ioport = IOPort.init(ret);
        ret.tmrb1 = TmrB1.init(ret);
        ret.cmp = Cmp.init(ret);
        ret.ssu = Ssu.init(ret);
        ret.tmrw = TmrW.init(ret);
        ret.pfcr = 0; ret.flmcr1 = 0; ret.flmcr2 = 0;
        ret.flpwr = 0; ret.ebr1 = 0; ret.fenr = 0;

        ret.aec = Aec.init(ret);
        ret.sci3 = Sci3.init(ret);
        ret.wdt = Wdt.init(ret);
        ret.adc = Adc.init(ret);
        ret.syscr1 = 0; ret.syscr2 = 0; ret.iegr = 0;
        ret.ienr1 = 0; ret.ienr2 = 0; ret.osscr = 0;
        ret.irr1 = 0; ret.irr2 = 0; ret.clkstpr1 = 0; ret.clkstpr2 = 0;

        ret.ram = @ptrCast(*[2*1024]u8, try alloc.alloc(u8, 2*1024));
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
        //c.h8300h_reset(&self.h8300h);

        self.rtc.reset();
        self.i2c.reset();
        self.ioport.reset();
        self.tmrb1.reset();
        self.cmp.reset();
        self.ssu.reset();
        self.tmrw.reset();

        self.pfcr = 0; self.flmcr1 = 0; self.flmcr2 = 0;
        self.flpwr = 0; self.ebr1 = 0; self.fenr = 0;

        self.aec.reset();
        self.sci3.reset();
        self.wdt.reset();
        self.adc.reset();
        self.syscr1 = 0; self.syscr2 = 0; self.iegr = 0;
        self.ienr1 = 0; self.ienr2 = 0; self.osscr = 0;
        self.irr1 = 0; self.irr2 = 0; self.clkstpr1 = 0; self.clkstpr2 = 0;

        for (self.ram[0..(2*1024)]) |_, i| self.ram[i] = 0;
        //std.mem.set([2*1024]u8, self.ram, 0);
    }

    pub fn run(self: *H838606F, inc: u64) void {
        self.sched.run(inc);
    }

    pub fn read8 (self: *H838606F, off: usize, comptime flags: BusAccess) u8  {
        if (off >= 0 and off < 48*1024) {
            if (flags.cycle) self.sched.cycle(2);
            return self.flash[off];
        } else if (off >= 0xf020 and off < 0xf100) {
            // IO1 TODO
            std.debug.print("read8 unknown IO1 address 0x{x:}\n", .{off});
            self.sched.ibreak();
            return undefined;
        } else if (off >= 0xfb80 and off < 0xff80) {
            if (flags.cycle) self.sched.cycle(2);
            return self.ram[off - 0xfb80];
        } else if (off >= 0xff80 and off <=0xffff) {
            // IO2 TODO
            std.debug.print("read8 unknown IO2 address 0x{x:}\n", .{off});
            self.sched.ibreak();
            return undefined;
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
            return (@as(u16, self.flash[off  ]) << 8)
                 |  @as(u16, self.flash[off+1]);
        } else if (off >= 0xf020 and off < 0xf100) {
            // IO1 TODO
            std.debug.print("read16 unknown IO1 address 0x{x:}\n", .{off});
            self.sched.ibreak();
            return undefined;
        } else if (off >= 0xfb80 and off < 0xff80) {
            // big-endian
            if (flags.cycle) self.sched.cycle(2);
            return (@as(u16, self.ram[off-0xfb80  ]) << 8)
                 |  @as(u16, self.ram[off-0xfb80+1]);
        } else if (off >= 0xff80 and off <=0xffff) {
            // IO2 TODO
            std.debug.print("read16 unknown IO2 address 0x{x:}\n", .{off});
            self.sched.ibreak();
            return undefined;
        } else {
            std.debug.print("read16 unknown WTF address 0x{x:}\n", .{off});
            self.sched.ibreak();
            return undefined;
        }
    }

    pub fn write8 (self: *H838606F, off: usize, v: u8 , comptime flags: BusAccess) void {
        if (off >= 0 and off < 48*1024) {
            if (flags.cycle) self.sched.cycle(2);
            self.flash[off] = v;
        } else if (off >= 0xf020 and off < 0xf100) {
            // IO1 TODO
            std.debug.print("write8 unknown IO1 address 0x{x:} <- 0x{x:}\n", .{off,v});
            self.sched.ibreak();
        } else if (off >= 0xfb80 and off < 0xff80) {
            if (flags.cycle) self.sched.cycle(2);
            self.ram[off-0xfb80] = v;
        } else if (off >= 0xff80 and off <=0xffff) {
            // IO2 TODO
            std.debug.print("write8 unknown IO2 address 0x{x:} <- 0x{x:}\n", .{off,v});
            self.sched.ibreak();
        } else {
            std.debug.print("write8 unknown WTF address 0x{x:} <- 0x{x:}\n", .{off,v});
            //self.sched.ibreak(); // written to on entry, ignore
        }
    }
    pub fn write16(self: *H838606F, off_: usize, v: u16, comptime flags: BusAccess) void {
        const off = off_ ^ (off_ & 1); // address must be aligned

        if (off >= 0 and off < 48*1024) {
            // big-endian
            if (flags.cycle) self.sched.cycle(2);
            self.flash[off  ] = @truncate(u8, v >> 8);
            self.flash[off+1] = @truncate(u8, v &255);
        } else if (off >= 0xf020 and off < 0xf100) {
            // IO1 TODO
            std.debug.print("write16 unknown IO1 address 0x{x:} <- 0x{x:}\n", .{off,v});
            self.sched.ibreak();
        } else if (off >= 0xfb80 and off < 0xff80) {
            // big-endian
            if (flags.cycle) self.sched.cycle(2);
            self.ram[off-0xfb80  ] = @truncate(u8, v >> 8);
            self.ram[off-0xfb80+1] = @truncate(u8, v &255);
        } else if (off >= 0xff80 and off <=0xffff) {
            // IO2 TODO
            std.debug.print("write16 unknown IO2 address 0x{x:} <- 0x{x:}\n", .{off,v});
            self.sched.ibreak();
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

