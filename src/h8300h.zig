
const std = @import("std");
const print = std.debug.print;

const interp = @import("h8300h/interp.zig");
const insn = @import("h8300h/insn.zig");

usingnamespace @import("h838606f.zig");

pub const State = enum {
    reset, exec, exn, bus, sleep, sw_standby, hw_standby
};
pub const CCR = enum(u8) { // TODO: flags enum?
    none = 0,
    i = 1<<7, U = 1<<6, h = 1<<5, u = 1<<4,
    n = 1<<3, z = 1<<2, v = 1<<1, c = 1<<0,
    _
};
pub const PendingExn = enum(u64) { // TODO: flags enum?
    none = 0,

    rst = 1<<0, nmi = 1<<7, trp0 = 1<<8, trp1 = 1<<9,
    trp2 = 1<<10, trp3 = 1<<11, slp = 1<<13,
    irq0 = 1<<16, irq1 = 1<<17, irqaec = 1<<18,
    comp0 = 1<<21, comp1 = 1<<22,
    rtc0s25 = 1<<23, rtc0s5 = 1<<24, rtc1s = 1<<25, rtc1m = 1<<26,
    rtc1h = 1<<27, rtc1d = 1<<28, rtc1w = 1<<29, rtcovf = 1<<30,
    wdt = 1<<31, aec = 1<<32, tmrb1 = 1<<33, ssu = 1<<34, tmrw = 1<<35,
    sci3 = 1<<37, adc = 1<<38
};

pub const H8300H = struct {
    sys: *H838606F,
    reg: [8]u32,
    pc: u16,
    fetch: u16,
    ccr: CCR,
    state: State,
    pending: PendingExn,

    pub fn stat(self: *const H8300H) void {
        // can't do this just in the print() call inline bc compiler bugs >__>
        var flags: [8]u8 = undefined;

        comptime var i = 0;
        inline while (i < 8) : (i += 1) {
            flags[i] = '-';
            const ev = @intToEnum(CCR, @as(u8,1)<<@truncate(u3,i));
            if (self.hasc(ev)) flags[i] = @tagName(ev)[0];
        }

        var args =
            .{self.pc,self.fetch,
                flags[7],flags[6],flags[5],flags[4],flags[3],flags[2],flags[1],flags[0],
                self.state,self.pending};
        print("pc=0x{x:4} fetched=0x{x:4} ccr={c}{c}{c}{c}{c}{c}{c}{c} state={} pending={}\n", args);
        print("er0=0x{x:8} er1=0x{x:8} er2=0x{x:8} er3=0x{x:8}\n",
            .{self.reg[0],self.reg[1],self.reg[2],self.reg[3]});
        print("er4=0x{x:8} er5=0x{x:8} er6=0x{x:8} er7=0x{x:8}\n",
            .{self.reg[4],self.reg[5],self.reg[6],self.reg[7]});
    }

    pub fn init(s: *H838606F) H8300H {
        return H8300H { .sys = s, .pc = 0, .ccr = .i, .reg = undefined,
            .state = .reset, .pending = .none, .fetch = 0
        };
    }
    pub fn reset(self: H8300H) void {
        self.pc = 0; self.ccr = .i; self.state = .reset; self.pending = .rst;
        self.fetch = 0;

        for (self.reg[0..8]) |_, i| self.reg[i] = 0;
    }

    pub inline fn cycle(self: *H8300H, c: u64) void { self.sys.sched.cycle(c); }
    pub inline fn skip(self: *H8300H) void { self.sys.sched.skip(); }

    // TODO: correct address cycle timing!
    // RAM, ROM: 16-bit bus, 2 cycles
    // MMIO/'internal': 8/16-bit bus, 3 cycles(?)
    // 'external': 8/16-bit bus, 2/3 cycles
    // => what is internal and what is external?????
    pub fn read8 (self: *H8300H, addr: u16) u8  {
        const r = self.sys.read8 (addr, .{.cycle=true,.eff=true});
        //self.cycle(2); // good enough for now
        return r;
    }
    pub fn read16(self: *H8300H, addr: u16) u16 {
        const r = self.sys.read16(addr, .{.cycle=true,.eff=true});
        //self.cycle(2); // good enough for now
        return r;
    }
    pub fn write8 (self: *H8300H, addr: u16, v: u8 ) void {
        self.sys.write8 (addr, v, .{.cycle=true,.eff=true});
        //self.cycle(2); // good enough for now
    }
    pub fn write16(self: *H8300H, addr: u16, v: u16) void {
        self.sys.write16(addr, v, .{.cycle=true,.eff=true});
        //self.cycle(2); // good enough for now
    }

    pub inline fn raise(self: *H8300H, newirq: PendingExn) void {
        self.orp(newirq);
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
                self.xorp(@intToEnum(PendingExn, @as(u64, 1) << i));
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

        self.write16(self.gsp() -% 2, self.pc);
        const ccru8 = @as(u8, @enumToInt(self.ccr));
        self.write16(self.gsp() -% 4, @as(u16, ccru8) | (@as(u16, ccru8) << 8));
        self.ssp(self.gsp() -% 4);

        self.pc = self.read16(evtaddr);

        self.orc(.i);
        self.fetch = self.read16(self.pc); self.pc +%= 2;

        self.state = .exec;
    }

    fn handle_exec(self: *H8300H) void {
        // TODO: if ldc(/stc?), do NOT go to exn state! AT ALL!
        if (self.pending != .none) {
            self.state = .exn; // !
            return;
        }
        //const insnlw = self.fetch;

        //self.fetch = self.read16(self.pc); self.pc += 2; // part of exec
        interp.exec(self);
    }

    pub fn runthread(self: *H8300H) void {
        while (true) {
            switch (self.state) {
                .reset => {
                    self.pc = self.read16(0x0000);
                    print("pc = 0x{x:04}, going rst->exec now... (pending: 0x{x})\n", .{self.pc, @enumToInt(self.pending)});
                    self.fetch = self.read16(self.pc); self.pc +%= 2;
                    //self.orp(.rst);
                    self.setp(.rst, .none);
                    self.state = .exec;
                },
                .exn => {
                    if (self.pending == .none) {
                        @panic("wtf, no pending but in exn state?");
                    }
                    self.handle_exn();
                },
                .exec => {
                    self.handle_exec();
                },
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

    // yuck yuck yuck yuck yuck
    pub inline fn setc(self: *H8300H, mask: CCR, val: CCR) void {
        self.ccr = @intToEnum(CCR, ((~@enumToInt(mask))&@enumToInt(self.ccr))|(@enumToInt(val)&@enumToInt(mask)));
    }
    pub inline fn andc(self: *H8300H, f: CCR) void {
        self.ccr = @intToEnum(CCR, @enumToInt(f)&@enumToInt(self.ccr));
    }
    pub inline fn andnc(self: *H8300H, f: CCR) void {
        self.ccr = @intToEnum(CCR, (~@enumToInt(f))&@enumToInt(self.ccr));
    }
    pub inline fn orc(self: *H8300H, f: CCR) void {
        self.ccr = @intToEnum(CCR, @enumToInt(f)|@enumToInt(self.ccr));
    }
    pub inline fn xorc(self: *H8300H, f: CCR) void {
        self.ccr = @intToEnum(CCR, @enumToInt(f)^@enumToInt(self.ccr));
    }
    pub inline fn hasc(self: *const H8300H, f: CCR) bool {
        const res = (@enumToInt(self.ccr) & @enumToInt(f));
        const rv = (@enumToInt(self.ccr) & @enumToInt(f)) != 0;
        return rv;
    }

    pub inline fn setp(self: *H8300H, mask: PendingExn, val: PendingExn) void {
        self.pending = @intToEnum(PendingExn, ((~@enumToInt(mask))&@enumToInt(self.pending))|(@enumToInt(val)&@enumToInt(mask)));
    }
    pub inline fn andp(self: *H8300H, f: PendingExn) void {
        self.pending = @intToEnum(PendingExn, @enumToInt(f)&@enumToInt(self.pending));
    }
    pub inline fn andnp(self: *H8300H, f: PendingExn) void {
        self.pending = @intToEnum(PendingExn, (~@enumToInt(f))&@enumToInt(self.pending));
    }
    pub inline fn orp(self: *H8300H, f: PendingExn) void {
        self.pending = @intToEnum(PendingExn, @enumToInt(f)|@enumToInt(self.pending));
    }
    pub inline fn xorp(self: *H8300H, f: PendingExn) void {
        self.pending = @intToEnum(PendingExn, @enumToInt(f)^@enumToInt(self.pending));
    }
    pub inline fn hasp(self: *const H8300H, f: PendingExn) bool {
        return (@enumToInt(self.pending) & @enumToInt(f)) != 0;
    }

    const isle = comptime std.Target.current.cpu.arch.endian() == .Little;
    const isbe = comptime std.Target.current.cpu.arch.endian() == .Big;
    const doptr = true and (isle or isbe);

    pub inline fn grh(self: *H8300H, i: anytype) u8 {
        if (doptr and !isle and !isbe) @compileError("um, better check your stuff");

        if (doptr) {
            if (isle) {
                return @ptrCast([*]u8, &self.reg[i])[1];
            } else if (isbe) {
                @ptrCast([*]u8, &self.reg[i])[2];
            } else unreachable;
        } else return @truncate(u8, self.reg[i] >> 8);
    }
    pub inline fn srh(self: *H8300H, i: anytype, nv: u8) void {
        if (doptr) {
            if (isle) {
                @ptrCast([*]u8, &self.reg[i])[1] = nv;
            } else if (isbe) {
                @ptrCast([*]u8, &self.reg[i])[2] = nv;
            } else unreachable;
        } else self.reg[i] = (self.reg[i] & 0xffff00ff) | (@as(u32, nv) << 8);
    }
    pub inline fn grl(self: *H8300H, i: anytype) u8 {
        if (doptr) {
            if (isle) {
                return @ptrCast([*]u8, &self.reg[i])[0];
            } else if (isbe) {
                return @ptrCast([*]u8, &self.reg[i])[3];
            } else unreachable;
        } else return @truncate(u8, self.reg[i] >> 0);
    }
    pub inline fn srl(self: *H8300H, i: anytype, nv: u8) void {
        if (doptr) {
            if (isle) {
                @ptrCast([*]u8, &self.reg[i])[0] = nv;
            } else if (isbe) {
                @ptrCast([*]u8, &self.reg[i])[3] = nv;
            } else unreachable;
        } else self.reg[i] = (self.reg[i] & 0xffffff00) | (@as(u32, nv) << 0);
    }
    pub inline fn gr(self: *H8300H, i: anytype) u16 {
        if (doptr) {
            if (isle) {
                return @ptrCast([*]u16, &self.reg[i])[0];
            } else if (isbe) {
                return @ptrCast([*]u16, &self.reg[i])[1];
            } else unreachable;
        } else return @truncate(u16, self.reg[i] >> 00);
    }
    pub inline fn sr(self: *H8300H, i: anytype, nv: u16) void {
        if (doptr) {
            if (isle) {
                @ptrCast([*]u16, &self.reg[i])[0] = nv;
            } else if (isbe) {
                @ptrCast([*]u16, &self.reg[i])[1] = nv;
            } else unreachable;
        } else self.reg[i] = (self.reg[i] & 0xffff0000) | (@as(u32, nv) << 00);
    }
    pub inline fn ge(self: *H8300H, i: anytype) u16 {
        if (doptr) {
            if (isle) {
                return @ptrCast([*]u16, &self.reg[i])[1];
            } else if (isbe) {
                return @ptrCast([*]u16, &self.reg[i])[0];
            } else unreachable;
        } else return @truncate(u16, self.reg[i] >> 16);
    }
    pub inline fn se(self: *H8300H, i: anytype, nv: u16) void {
        if (doptr) {
            if (isle) {
                @ptrCast([*]u16, &self.reg[i])[1] = nv;
            } else if (isbe) {
                @ptrCast([*]u16, &self.reg[i])[0] = nv;
            } else unreachable;
        } else self.reg[i] = (self.reg[i] & 0x0000ffff) | (@as(u32, nv) << 16);
    }

    pub inline fn gsp(self: *H8300H) u16 { return self.gr(7); }
    pub inline fn ssp(self: *H8300H, nsp: u16) void { self.sr(7, nsp); }

    pub inline fn ghl(self: *H8300H, o: insn.OpRnHL) u8 {
        const i = @enumToInt(o);
        if ((i & 8) == 0) { // h
            return self.grh(i & 7);
        } else { // l
            return self.grl(i & 7);
        }
    }
    pub inline fn shl(self: *H8300H, o: insn.OpRnHL, v: u8) void {
        const i = @enumToInt(o);
        if ((i & 8) == 0) { // h
            self.srh(i & 7, v);
        } else { // l
            self.srl(i & 7, v);
        }
    }
    pub inline fn grn(self: *H8300H, o: insn.OpRn) u16 {
        const i = @enumToInt(o);
        if ((i & 8) == 0) { // r
            return self.gr(i & 7);
        } else { // e
            return self.ge(i & 7);
        }
    }
    pub inline fn srn(self: *H8300H, o: insn.OpRn, v: u16) void {
        const i = @enumToInt(o);
        if ((i & 8) == 0) { // r
            self.sr(i & 7, v);
        } else { // e
            self.se(i & 7, v);
        }
    }
    pub inline fn ger(self: *H8300H, i: insn.OpERn) u32 {
        return self.reg[@enumToInt(i)];
    }
    pub inline fn ser(self: *H8300H, i: insn.OpERn, nv: u32) void {
        self.reg[@enumToInt(i)] = nv;
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

