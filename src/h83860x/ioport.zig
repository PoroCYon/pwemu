
const std = @import("std");

const H838606F = @import("../h838606f.zig").H838606F;

pub const IOPort = struct {
    sys: *H838606F,

    pdr1: u3, // p1 data: lowest 3 bits. if read in output mode, returns stored output data
    pcr1: u3, // p1 control: bit hi = data pin is output, input otherwise
    pucr1: u3, // p1 pullup cr: if in input mode: bit hi = MOS pullup, bit lo = NC/Z
    // p1 mode:
    // * bit 5: p1.2: lo == IO pin, hi == IRQAEC input, AECPWM output (depending on AEGSR)
    // * bit 4,3: p1.1:
    //     'b00 == IO pin
    //     'b01 == AEVL input
    //     'b1x == FTCI input
    //     NOTE: if PFCR configured, always /IRQ1 regardless of PMR1!
    // * bit 2,1,0: p1.0:
    //     'b000: IO pin or FTIOA pin (depending on TIOR0)
    //     'b001: AEVH in
    //     'b01x: TMOW
    //     'b100: CLKOUT phi_osc/1
    //     'b101: CLKOUT phi_osc/2
    //     'b110: CLKOUT phi_osc/4
    //     'b111: illegal
    pmr1: u6,

    pdr3: u3, // p3 data: lowest 3 bits
    pcr3: u3, // p3 control: hi=output, lo=input
    pucr3: u3, // p3 pullup: if input: hi=pullup, lo=NC
    pmr3: u1, // p3 mode: lo=p3.0 IO or sck3, hi=vcref
    // p3.2: P32 (SPCR C3 lo) or TXD3 or IrTXD (SPCR C3 hi, depending on IrCR)
    // p3.1: P31 (SCR2 RE lo) or RXD3 or IrRXD (SCR2 RE hi, depending on IrCR)
    // p3.0: P30 (PFCR !=b10, SCR3 CKE lo, SMR3 COM lo)
    //    or sck3 in/out (SMR3 COM hi or SCR3 SCE)
    //    or VCref (PMR3)
    //    or IRQ0 (PFCR == 'b10)

    pdr8: u3, // p8.{4,3,2} data (yes, those 3 bits)
    pcr8: u3, // p8 control: in/out
    pucr8: u3,
    // p8.4:
    //   TMRW PWMD hi: FTIOD out
    //   TIOR1.IOD='b1xx: p84/FTIOD in/out
    //   TIOR1.IOD='b01x: FTIOD out
    //   TIOR1.IOD='b001: FTIOD out
    //   otherwise: P84
    // p8.3, p8.2 are similar (but FTIOC, FTIOB)

    pdr9: u4,
    pcr9: u4,
    podr9: u4, // 'open-drain': hi=NMOS open-drain, lo=CMOS output
    pucr9: u4,
    // p9.3:
    //   PFCR.IRQ1S=='b01: /IRQ1 in
    //   SSI or /SCS vs P93 depending on ? ? ?
    // p9.2:
    //   PFCR.IRQ0S=='b01: /IRQ0 in
    //   SSO or SSCK vs P92 depending on ? ? ?
    // p9.1:
    //   P91 vs SSCK vs SSO vs SDA depending on ? ? ?
    // p9.0:
    //   P90 vs /SCS vs SSI vs SCL depending on ? ? ?

    //pdrb: u6,
    pmrb: u4, // bits 0,1,3!
    // pmrb.0: pb0: lo=PB0/AN0 in, hi=/IRQ0
    // pmrb.1: pb1: lo=PB1/AN1 in, hi=/IRQ1
    // pmrb.3: test/adtrg: lo=TEST, hi=/ADTRG in
    // AMR.CH=='b1001: pb5==AN5 in, else PB5/COMP1 in
    // AMR.CH=='b1000: pb4==AN4 in, else PB4/COMP0 in
    // AMR.CH=='b0111: pb3==AN3 in, else PB3 in
    // AMR.CH=='b0110: pb2==AN2 in, else PB2 in
    // PMRB.1 hi: /IRQ1 in, else: AMR.CH=='b0101: pb1==AN1 in, else PB1 in
    // PMRB.0 hi: /IRQ0 in, else: AMR.CH=='b0100: pb0==AN0 in, else PB0 in

    pfcr: u5,
    // pfcr.4: lo: {SSI,SSO,SSCK,/SCS} = p9.{3,2,1,0}, hi: {SSI,SSO,SSCK,/SCS} = p9.{0,1,2,3}
    // pfcr.{3,2}: /IRQ1 = 'b00: PB1
    //                     'b01: P93
    //                     'b10: P11
    //                     'b11: illegal
    // pfcr.{1,0}: /IRQ0 = 'b00: PB0
    //                     'b01: P92
    //                     'b10: P30
    //                     'b11: illegal

    pub fn init(s: *H838606F) IOPort {
        return IOPort { .pucr8 = 0, .pucr9 = 0, .podr9 = 0,
            .pmr1 = 0, .pmr3 = 0, .pmrb = 0, //.pdrb = 0,
            .pdr1 = 0, .pdr3 = 0, .pdr8 = 0, .pdr9 = 0,
            .pucr1 = 0, .pucr3 = 0,
            .pcr1 = 0, .pcr3 = 0, .pcr8 = 0, .pcr9 = 0,
            .pfcr = 0,
            .sys = s,
        };
    }
    pub fn reset(self: *IOPort) void {
        self.pucr8 = 0;
        self.pucr9 = 0;
        self.podr9 = 0;

        self.pmr1 = 0;
        self.pmr3 = 0;
        self.pmrb = 0;

        self.pdr1 = 0;
        self.pdr3 = 0;
        self.pdr8 = 0;
        self.pdr9 = 0;
        //self.pdrb = 0;

        self.pucr1 = 0;
        self.pucr3 = 0;

        self.pcr1 = 0;
        self.pcr3 = 0;
        self.pcr8 = 0;
        self.pcr9 = 0;

        self.pfcr = 0;
    }

    pub fn write8 (self: *IOPort, off: usize, v: u8 ) void {
        switch (off) {
            // IO1
            0xf085 => self.pfcr = @truncate(u5,v),
            0xf086 => self.pucr8 = @truncate(u3,v>>2),
            0xf087 => self.pucr9 = @truncate(u4,v),
            0xf08c => self.podr9 = @truncate(u4,v),

            // IO2
            0xffc0 => self.pmr1 = @truncate(u6,v),
            0xffc2 => self.pmr3 = @truncate(u1,v),
            0xffca => self.pmrb = @truncate(u4,v&0xb),
            0xffd4 => {
                self.pdr1 = @truncate(u3,v);
                // TODO => stuff!
                self.sys.iface.write_io(self.sys.ud, 1,
                    @as(u8,self.pdr1 & self.pcr1), @as(u8,self.pcr1));
            }, 0xffd6 => {
                self.pdr3 = @truncate(u3,v);
                // TODO => stuff!
                self.sys.iface.write_io(self.sys.ud, 3,
                    @as(u8,self.pdr3 & self.pcr3), @as(u8,self.pcr3));
            }, 0xffdb => {
                self.pdr8 = @truncate(u3,v>>2);
                // TODO => stuff!
                self.sys.iface.write_io(self.sys.ud, 8,
                    @as(u8,self.pdr8 & self.pcr8), @as(u8,self.pcr8));
            }, 0xffdc => {
                self.pdr9 = @truncate(u4,v);
                // TODO => stuff!
                self.sys.iface.write_io(self.sys.ud, 9,
                    @as(u8,self.pdr9 & self.pcr9), @as(u8,self.pcr9));
            },
            0xffe0 => self.pucr1 = @truncate(u3,v),
            0xffe1 => self.pucr3 = @truncate(u3,v),
            0xffe4 => self.pcr1 = @truncate(u3,v),
            0xffe6 => self.pcr3 = @truncate(u3,v),
            0xffeb => self.pcr8 = @truncate(u3,v>>2),
            0xffec => self.pcr9 = @truncate(u4,v),

            else => {
                std.debug.print("write8 unknown IOport address 0x{x:} <- 0x{x:}\n", .{off,v});
                self.sys.sched.ibreak();
            }
        }
    }
    pub inline fn write16(self: *IOPort, off: usize, v: u16) void {
        self.write8(off&0xfffe, @truncate(u8, v >> 8));
        self.write8(off|0x0001, @truncate(u8, v >> 0));
    }

    pub fn read8 (self: *IOPort, off: usize) u8  {
        return switch (off) {
            // IO1
            0xf085 => @as(u8,self.pfcr),
            0xf086 => @as(u8,self.pucr8<<2),
            0xf087 => @as(u8,self.pucr9),
            0xf08c => @as(u8,self.podr9),

            // IO2
            0xffc0 => @as(u8,self.pmr1),
            0xffc2 => @as(u8,self.pmr3),
            0xffca => @as(u8,self.pmrb),
            0xffd4 => blk: {
                break :blk @as(u8,self.pdr1 & self.pcr1)
                       | (self.sys.iface.read_io(self.sys.ud, 1) & @as(u8,~self.pcr1));
            }, 0xffd6 => blk: {
                break :blk @as(u8,self.pdr3 & self.pcr3)
                       | (self.sys.iface.read_io(self.sys.ud, 3) & @as(u8,~self.pcr3));
            }, 0xffdb => blk: {
                break :blk @as(u8,(self.pdr8 & self.pcr8)<<2)
                       | (@truncate(u8,self.sys.iface.read_io(self.sys.ud, 8)<<2) & @as(u8,(~self.pcr8)<<2));
            }, 0xffdc => blk: {
                break :blk @as(u8,self.pdr9 & self.pcr9)
                       | (self.sys.iface.read_io(self.sys.ud, 9) & @as(u8,~self.pcr9));
            }, 0xffde => blk: {
                // TODO => mask out bits used for ADC input
                break :blk self.sys.iface.read_io(self.sys.ud, 0xb);
            },
            0xffe0 => @as(u8,self.pucr1),
            0xffe1 => @as(u8,self.pucr3),
            0xffe4 => @as(u8,self.pcr1),
            0xffe6 => @as(u8,self.pcr3),
            0xffeb => @as(u8,@as(u5,self.pcr8)<<2),
            0xffec => @as(u8,self.pcr9),

            else => blk: {
                std.debug.print("read8 unknown IOport address 0x{x:}\n", .{off});
                self.sys.sched.ibreak();
                break :blk undefined;
            }
        };
    }
    pub inline fn read16(self: *IOPort, off: usize) u16 {
        return (@as(u16, self.read8(off&0xfffe)) << 8)
             | (@as(u16, self.read8(off|0x0001)) << 0);
    }
};

