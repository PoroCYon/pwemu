
const std = @import("std");
const print = std.debug.print;

const interp = @import("h8300h/interp.zig");

usingnamespace @import("h838606f.zig");

pub const H8300H = struct {
    sys: *H838606F,
    reg: [8]u32,
    pc: u16,
    fetch: u16,
    ccr: CCR,
    state: State,
    pending: PendingExn,

    pub fn stat(self: *const H8300H) void {
        print("pc=0x{x:4} fetched=0x{x:4} ccr={} state={} pending={}\n",
            .{self.pc,self.fetch,self.ccr,self.state,self.pending});
        print("er0=0x{x:8} er1=0x{x:8} er2=0x{x:8} er3=0x{x:8}\n",
            .{self.reg[0],self.reg[1],self.reg[2],self.reg[3]});
        print("er4=0x{x:8} er5=0x{x:8} er6=0x{x:8} er7=0x{x:8}\n",
            .{self.reg[4],self.reg[5],self.reg[6],self.reg[7]});
    }

    inline fn sp(self: *H8300H) u16 { return @truncate(u16, self.reg[7]); }
    inline fn ssp(self: *H8300H, nsp: u16) void {
        self.reg[7] = (self.reg[7] & 0xffff0000) | @as(u32, nsp);
    }

    pub fn init(s: *H838606F) H8300H {
        return H8300H { .sys = s, .pc = 0, .ccr = .i, .reg = undefined,
            .state = .reset, .pending = .rst, .fetch = 0
        };
    }
    pub fn reset(self: H8300H) void {
        self.pc = 0; self.ccr = .i; self.state = .reset; self.pending = .rst;
        self.fetch = 0;

        for (self.reg[0..8]) |_, i| self.reg[i] = 0;
    }

    pub inline fn cycle(self: *H8300H, c: u64) void { self.sys.sched.cycle(c); }
    pub inline fn skip(self: *H8300H) void { self.sys.sched.skip(); }

    pub const State = enum {
        reset, exec, exn, bus, sleep, sw_standby, hw_standby
    };
    pub const CCR = enum(u8) { // TODO: flags enum?
        i = 1<<7, ui= 1<<6, h = 1<<5, u = 1<<4,
        n = 1<<3, z = 1<<2, v = 1<<1, c = 1<<0
    };
    pub const PendingExn = enum(u64) { // TODO: flags enum?
        none = 0,

        rst = 1<<0, nmi = 1<<7, trp0 = 1<<8, trp1 = 1<<9,
        trp2 = 1<<10, trp3 = 1<<11, slp = 1<<13,
        // TODO: irq0/irq1/irqaec, all other interrupts!
        irq = 1<<16 // check irr/irr2
    };

    // TODO: correct address cycle timing!
    // RAM, ROM: 16-bit bus, 2 cycles
    // MMIO/'internal': 8/16-bit bus, 3 cycles(?)
    // 'external': 8/16-bit bus, 2/3 cycles
    // => what is internal and what is external?????
    pub fn read8 (self: *H8300H, addr: u16) u8  {
        const r = self.sys.read8 (addr);
        self.cycle(2); // good enough for now
        return r;
    }
    pub fn read16(self: *H8300H, addr: u16) u16 {
        const r = self.sys.read16(addr);
        self.cycle(2); // good enough for now
        return r;
    }
    pub fn write8 (self: *H8300H, addr: u16, v: u8 ) void {
        self.sys.write8 (addr, v);
        self.cycle(2); // good enough for now
    }
    pub fn write16(self: *H8300H, addr: u16, v: u16) void {
        self.sys.write16(addr, v);
        self.cycle(2); // good enough for now
    }

    fn handle_exn(self: *H8300H) void {
        // finish insn prefetch
        self.fetch = self.read16(self.pc); self.pc += 2;

        var evtaddr: u16 = undefined;
        var hasea = false;

        var i: u6 = 1; // skip rst
        while (i < 16) : (i += 1) {
            //if (i >= 8 and i <= 11) { // TRAPA has lowest prio.
            //    continue;             // or not? docs are inconsistent abt it (but I belive this more)
            //}
            if ((@enumToInt(self.pending) & (@as(u64, 1) << i)) != 0) {
                print("exn {}: load pc... ", .{i});
                evtaddr = i << 1;
                hasea = true;

                // these are edge-triggered (IRQs are level-triggered &
                // stoppable by setting the irq flag bits), so the flag
                // has to be removed here
                // TODO: unclear if internal irqs are edge- or level-triggered,
                //               and how to reset them if it's the latter case
                //               // might even be case-by-case???
                self.pending = @intToEnum(PendingExn, @enumToInt(self.pending) ^ (@as(u64, 1) << i));
                break;
            }
        }
        if (!hasea) {
            if ((@enumToInt(self.ccr) & @enumToInt(CCR.i)) == 0) {
                // still here? must be a regular IRQ
                // TODO: get irr1, irr2, check which exn to cause, etc.
                @panic("yelp, IRQ TBI...\n");

                // if (irri0 && ien0) || (irri1 && ien1) || (irrec2 && ienec2) || (irrad && ienad)
            }
        }
//        if (!hasea) {
//            i = 8; // TRAPA
//            while (i < 12) : (i += 1) {
//                if ((self.pending & @bitCast(PendingExn, 1 << i)) != .none) {
//                    print("exn {}: load pc... ", .{i});
//                    evtaddr = i << 1;
//                    hasea = true;
//
//                    // these are edge-triggered (IRQs are level-triggered &
//                    // stoppable by setting the irq flag bits), so the flag
//                    // has to be removed here
//                    self.pending ^= @bitCast(PendingExn, 1 << i);
//                    break;
//                }
//            }
//        }
        if (!hasea) {
            // ¯\_(ツ)_/¯
            self.state = .exec;
            return;
        }

        _ = self.read16(evtaddr); // discarded fsr
        self.cycle(2);

        self.write16(self.sp() - 2, self.pc);
        const ccru8 = @as(u8, @enumToInt(self.ccr));
        self.write16(self.sp() - 4, @as(u16, ccru8) | (@as(u16, ccru8) << 8));
        self.ssp(self.sp() + 4);

        self.pc = self.read16(evtaddr);

        self.ccr = @intToEnum(CCR, @enumToInt(self.ccr) | @enumToInt(CCR.i));
        self.fetch = self.read16(self.pc); self.pc += 2;

        self.state = .exec;
    }

    fn handle_exec(self: *H8300H) void {
        // TODO: if ldc(/stc?), do NOT go to exn state! AT ALL!
        //const insnlw = self.fetch;

        //self.fetch = self.read16(self.pc); self.pc += 2; // part if exec
        interp.exec(self);
    }

    pub fn runthread(self: *H8300H) void {
        while (true) {
            switch (self.state) {
                .reset => {
                    self.pc = self.read16(0x0000);
                    print("pc = 0x{x:04}, going rst->exec now...\n", .{self.pc});
                    self.fetch = self.read16(self.pc); self.pc += 2;
                    self.pending = @intToEnum(PendingExn, @enumToInt(self.pending) ^ @enumToInt(PendingExn.rst));
                    self.state = .exec;
                },
                .exn => {
                    if (self.pending == .none) {
                        @panic("wtf, no pending but in exn state?");
                    }
                    self.handle_exn();
                },
                .exec => self.handle_exec(),
                .bus => {
                    // bus released (to periph): wait until reattach,
                    // then either go to exn or exec?
                    self.cycle(256);
                },
                .sw_standby => {
                    // if external irq (== nmi/irq0/irq1/irqaec): goto exn, else stay in sleep
                    self.cycle(256);
                },
                .hw_standby => {
                    // if external rst: goto rst, else stay
                    self.skip();
                },
                .sleep => {
                    // if irq (internal or external): goto exn, else stay
                    self.cycle(16);
                }
            }
        }
    }
};

// Rn: register direct
// @Rn: register indirect
// @(d:(16|24), ERn): reg. indirect with offset
// @ERn+, @-ERn: post-inc/pre-dec ---> @Rn+: carries to En!
// @aa:(8|16|24): absolute addr
// 8-bit: "zeropage:" H'00xx (evt!) OR H'FFFFxx ???? prolly the latter
//   * H'0000xx for jmp/jsr, H'FFFFxx for all the rest??!
//   * former only for memory-indirect????
// 16-bit: sign-extension!
// #xx:(8|16|32): immediate
// @(d:(8|16),pc): pcrel
// @@aa:8: mem-indirect (8-bit: H'0000xx)

// "8/16/32-bit addsub: 125 ns" -> "2 states"
// "8x8 mul: 875 ns" -> "14 states"
// "16/8 div: 875 ns" -> "14 states"
// "16x16 mul: 1375 ns" -> "22 states"
// "32/16 div: 1375 ns" -> "22 states"
// ^ which clock? (16 MHz?)

// call: push pc (16 in normal, 24 in adv+8bit reserved)
// exn: push pc, ccr (ignored) (normal), pc hi (adv), ccr

// 'advanced mode' disabled???? //// yep
//
// evt: always at h'0, 32-bit in adv mode, 16 in normal

// on reset: ccr_i set, all other regs UNDEFINED!
// w/l-bit accesses: needs even alignment! (16-bit bus?); lowest bit ignored
// stack operations always w or l

