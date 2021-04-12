
const std = @import("std");
const print = std.debug.print;
const expect = @import("std").testing.expect;

usingnamespace @import("insn.zig");
const decode = @import("decode.zig");

usingnamespace @import("../h8300h.zig");

const HFn = fn(*H8300H, Insn, []const u16)void;

const HRow = struct {
    tag: Opcode,
    handler: HFn
};

inline fn xor(a: bool, b: bool) bool { // zig, *please*
    return (@boolToInt(a) ^ @boolToInt(b)) != 0;
}

fn mk_me_a_magic_fn(comptime i: comptime_int, myself: anytype) fn(*H8300H, Insn, []const u16)void {
    const the_tag = @intToEnum(Opcode, i);
    const real_hfn = @field(myself, "handle_" ++ @tagName(the_tag));

    return (struct {
        pub fn a(self: *H8300H, insn: Insn, raw: []const u16) void {
            //print("in magic fn #{} for tag {}\n", .{i, the_tag});
            ////insn.display();
            switch (insn) {
                the_tag => |d| real_hfn(self, insn, d, raw),
                else => unreachable
            }
        }
    }).a;
}

const insntab = comptime blk: {
    comptime const ninsn = switch (@typeInfo(Opcode)) {
        .Enum => |e| blk2: {
            if (!e.is_exhaustive) @compileError("wtf!");
            break :blk2 e.fields.len;
        },
        else => @compileError("wtf")
    };
    var rv: [ninsn]HRow = undefined;

    var i = 0;
    while (i < ninsn) : (i += 1) {
        const the_tag = @intToEnum(Opcode, i);

        rv[i] = HRow {
            .tag = the_tag,
            .handler = mk_me_a_magic_fn(i, @This()) // need this so 'i' doesn't end up being 226/xorc for all entries
//            (struct {
//                pub fn a(self: *H8300H, insn: Insn, raw: []const u16) void {
//                    print("in magic fn #{} for tag {}\n", .{i, the_tag});
//                    //insn.display();
//                    switch (insn) {
//                        the_tag => |d| real_hfn(self, insn, d, raw),
//                        else => unreachable
//                    }
//                }
//            }).a
        };
    }

    break :blk rv;
};

pub fn exec(self: *H8300H) void {
    const possible_words = [_]u16{
        self.fetch,
        self.sys.read16(self.pc+0, .{.cycle=false,.eff=false}),
        self.sys.read16(self.pc+2, .{.cycle=false,.eff=false}),
        self.sys.read16(self.pc+4, .{.cycle=false,.eff=false}),
        self.sys.read16(self.pc+6, .{.cycle=false,.eff=false})
    };
    const insn = decode.decodeA(5, possible_words) orelse {
        print("unrecognised opcode, fetch=H'{x:4} pc=H'{x:4}\n",
            .{ self.fetch, self.pc });

        @panic("illegal insn!");
    };
    //insn.display();
    //self.stat();

    //print("table index #{}, tag {}\n", .{@enumToInt(@as(Opcode, insn)), @as(Opcode, insn)});
    const hrow = insntab[@enumToInt(@as(Opcode, insn))];
    hrow.handler(self, insn, possible_words[0..insn.size()]);

    //self.pc = @truncate(u16, self.pc + insn.size() * 2);
    //self.cycle((insn.size()-1)*2);
    //self.fetch = self.read16(self.pc - 2);
}

/// finish current insturction fetch
fn finf(self: *H8300H, raw: []const u16) void {
    var i: usize = 1;
    while (i < raw.len) : (i += 1) {
        self.fetch = self.read16(self.pc);
        self.pc +%= 2;
    }
}
/// next instruction fetch start
inline fn next(self: *H8300H) void {
    self.fetch = self.read16(self.pc);
    self.pc +%= 2;
}

const Arithsub = enum {
    add, sub, neg
};
/// set n, z, v, c, h according to result
fn flg_arith(comptime T: type, self: *H8300H, a: T, b: T, v: T, comptime x: bool, comptime sub: Arithsub) void {
    const rm = (v >> (@bitSizeOf(T)-1)) != 0;
    const sm = (a >> (@bitSizeOf(T)-1)) != 0;
    const dm = (b >> (@bitSizeOf(T)-1)) != 0;

    const rm4 = ((v >> (@bitSizeOf(T)-1-4))&1) != 0;
    const sm4 = ((a >> (@bitSizeOf(T)-1-4))&1) != 0;
    const dm4 = ((b >> (@bitSizeOf(T)-1-4))&1) != 0;

    const zzz = self.hasc(.z);
    self.andc(@intToEnum(CCR, 0xd0)); // i, u, ui
    switch (sub) {
        .add => {
            if ((sm and dm) or (dm and !rm) or (sm and !rm)) self.orc(.c);
            if ((sm and dm and !rm) or (!sm and !dm and rm)) self.orc(.v);
            if ((sm4 and dm4) or (dm4 and !rm4) or (sm4 and !rm4)) self.orc(.h);
        },
        .sub => {
            if ((sm and !dm) or (!dm and rm) or (sm and rm)) self.orc(.c);
            if ((!sm and dm and !rm) or (sm and !dm and rm)) self.orc(.v);
            if ((sm4 and !dm4) or (!dm4 and rm4) or (sm4 and rm4)) self.orc(.h);
        },
        .neg => {
            if (dm or rm) self.orc(.c);
            if (dm and rm) self.orc(.v);
            if (dm4 or rm4) self.orc(.h);
        }
    }
    // add: sm &  dm |  dm & !rm | sm & !rm
    // sub: sm & !dm | !dm &  rm | sm &  rm
    // neg: dm |  rm
    //if ((sm and dm) or (dm and !rm) or (sm and !rm)) self.orc(.c);
    // add:  sm & dm & !rm | !sm & !dm & rm
    // sub: !sm & dm & !rm |  sm & !dm & rm
    // neg:  dm & rm
    //if ((sm and dm and !rm) or (!sm and !dm and rm)) self.orc(.v);
    // add: sm4 &  dm4 |  dm4 & !rm4 | sm4 & !rm4
    // sub: sm4 & !dm4 | !dm4 &  rm4 | sm4 &  rm4
    // neg: dm4 | rm4
    //if ((sm4 and dm4) or (dm4 and !rm4) or (sm4 and !rm4)) self.orc(.h);

    if (x) {
        if ((v == 0) and !zzz) self.orc(.z);
    } else {
        if (v == 0) self.orc(.z);
    }
    if (rm) self.orc(.n);
}
/// set z, n according to result
fn flg_logic(comptime T: type, self: *H8300H, v: T) void {
    self.andc(@intToEnum(CCR, 0xd0|36)); // i, u, ui, h, c
    if (v == 0) self.orc(.z);
    if ((v >> (@bitSizeOf(T)-1)) != 0) self.orc(.n);
}
/// set n, z, v and maybe c according to the result
fn flg_shro(comptime T: type, self: *H8300H, d: T, r: T, c: bool) void {
    self.andc(@intToEnum(CCR, 0xf0));

    if ((r >> (@bitSizeOf(T)-1)) != 0) self.orc(.n);
    if (r == 0) self.orc(.z);
    if (c) self.orc(.c);
}
/// set n, z according to result, clear v
fn flg_mov(comptime T: type, self: *H8300H, v: T) void {
    self.andc(@intToEnum(CCR, 0xf1));
    if ((v >> (@bitSizeOf(T)-1)) != 0) self.orc(.n);
    if (v == 0) self.orc(.z);
}

fn handle_add_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, false, .add);

    next(self);

    //print("handler for add_b_imm\n", .{});
    //insn.display();
}
fn handle_add_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = a +% b;
    self.srn(oands.b, r);
    flg_arith(u16, self, a, b, r, false, .add);

    next(self);

    //print("handler for add_w_imm\n", .{});
    //insn.display();
}
fn handle_add_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = a +% b;
    self.ser(oands.b, r);
    flg_arith(u32, self, a, b, r, false, .add);

    next(self);

    //print("handler for add_l_imm\n", .{});
    //insn.display();
}
fn handle_add_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, false, .add);

    next(self);

    //print("handler for add_b_rn\n", .{});
    //insn.display();
}
fn handle_add_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = a +% b;
    self.srn(oands.b, r);
    flg_arith(u16, self, a, b, r, false, .add);

    next(self);

    //print("handler for add_w_rn\n", .{});
    //insn.display();
}
fn handle_add_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = a +% b;
    self.ser(oands.b, r);
    flg_arith(u32, self, a, b, r, false, .add);

    next(self);

    //print("handler for add_l_rn\n", .{});
    //insn.display();
}
fn handle_adds(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    self.ser(oands.b, self.ger(oands.b) +% oands.a.val());
    next(self);

    //print("handler for adds\n", .{});
    //insn.display();
}
fn handle_addx_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, true, .add);

    next(self);

    //print("handler for addx_imm\n", .{});
    //insn.display();
}
fn handle_addx_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, true, .add);

    next(self);

    //print("handler for addx_rn\n", .{});
    //insn.display();
}
fn handle_and_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a & b;
    self.shl(oands.b, r);
    flg_logic(u8, self, r);

    next(self);

    //print("handler for and_b_imm\n", .{});
    //insn.display();
}
fn handle_and_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = a & b;
    self.srn(oands.b, r);
    flg_logic(u16, self, r);

    next(self);

    //print("handler for and_w_imm\n", .{});
    //insn.display();
}
fn handle_and_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = a & b;
    self.ser(oands.b, r);
    flg_logic(u32, self, r);

    next(self);

    //print("handler for and_l_imm\n", .{});
    //insn.display();
}
fn handle_and_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a & b;
    self.shl(oands.b, r);
    flg_logic(u8, self, r);

    next(self);

    //print("handler for and_b_rn\n", .{});
    //insn.display();
}
fn handle_and_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = a & b;
    self.srn(oands.b, r);
    flg_logic(u16, self, r);

    next(self);

    //print("handler for and_w_rn\n", .{});
    //insn.display();
}
fn handle_and_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = a & b;
    self.ser(oands.b, r);
    flg_logic(u32, self, r);

    next(self);

    //print("handler for and_l_rn\n", .{});
    //insn.display();
}
fn handle_andc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    self.andc(@intToEnum(CCR, oands));

    next(self);

    //print("handler for andc\n", .{});
    //insn.display();
}
fn handle_bcc_pcrel8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    next(self);

    const offu16 = if ((oands.a & 0x80) != 0) (0xff00 | @as(u16, oands.a))
                   else @as(u16, oands.a);
    const ea = self.pc +% offu16 -% 2; // correct wrt prefetch
    const branch = switch (oands.cc) {
        .a => true, .n => false,
        .hi => !self.hasc(.c) and !self.hasc(.z),
        .ls =>  self.hasc(.c) or   self.hasc(.z),
        .cc => !self.hasc(.c), .cs => self.hasc(.c),
        .ne => !self.hasc(.z), .eq => self.hasc(.z),
        .vc => !self.hasc(.v), .vs => self.hasc(.v),
        .pl => !self.hasc(.n), .mi => self.hasc(.n),
        .ge => !xor(self.hasc(.n), self.hasc(.v)),
        .lt =>  xor(self.hasc(.n), self.hasc(.v)),
        .gt => !xor(self.hasc(.n), self.hasc(.v)) and !self.hasc(.z),
        .le =>  xor(self.hasc(.n), self.hasc(.v)) or   self.hasc(.z),
    };

    if (branch) {
        self.pc = ea;
        next(self);
    } else _ = self.read16(ea);

    //print("handler for bcc_pcrel8\n", .{});
    //insn.display();
}
fn handle_bcc_pcrel16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    self.cycle(2);

    const ea = self.pc +% oands.a; // do NOT correct wrt prefetch
    const branch = switch (oands.cc) {
        .a => true, .n => false,
        .hi => !self.hasc(.c) and !self.hasc(.z),
        .ls =>  self.hasc(.c) or   self.hasc(.z),
        .cc => !self.hasc(.c), .cs => self.hasc(.c),
        .ne => !self.hasc(.z), .eq => self.hasc(.z),
        .vc => !self.hasc(.v), .vs => self.hasc(.v),
        .pl => !self.hasc(.n), .mi => self.hasc(.n),
        .ge => !xor(self.hasc(.n), self.hasc(.v)),
        .lt =>  xor(self.hasc(.n), self.hasc(.v)),
        .gt => !xor(self.hasc(.n), self.hasc(.v)) and !self.hasc(.z),
        .le =>  xor(self.hasc(.n), self.hasc(.v)) or   self.hasc(.z),
    };

    if (branch) {
        self.pc = ea;
        next(self);
    } else next(self);//self.fetch = self.read16(ea);

    //print("handler for bcc_pcrel16\n", .{});
    //insn.display();
    //self.stat();
}
fn handle_bsr_pcrel8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    const p = self.pc;
    next(self);

    const offu16 = if ((oands & 0x80) != 0) (0xff00 | @as(u16, oands))
                   else @as(u16, oands);
    const ea = p +% offu16;
    const s = self.gsp() -% 2;

    print("bsr pcrel8: pc=0x{x:}, sp=0x{x:}\n", .{ea, s});
    self.stat();

    self.pc = ea;
    next(self);

    self.ssp(s);
    self.write16(s, p);

    //print("handler for bsr_pcrel8\n", .{});
    //insn.display();
}
fn handle_bsr_pcrel16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    const p = self.pc;
    self.cycle(2);

    const ea = p +% oands;
    const s = self.gsp() -% 2;

    print("bsr pcrel16: pc=0x{x:}, sp=0x{x:}\n", .{ea, s});
    self.stat();

    self.pc = ea;
    next(self);

    self.ssp(s);
    self.write16(s, p);

    //print("handler for bsr_pcrel16\n", .{});
    //insn.display();
}
fn handle_band_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r != 0) .c else .none);

    next(self);
    //print("handler for band_rn\n", .{});
    //insn.display();
}
fn handle_band_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r != 0) .c else .none);

    next(self);
    //print("handler for band_Mern\n", .{});
    //insn.display();
}
fn handle_band_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const m = self.read8(@as(u16, oands.b) | 0xff00);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r != 0) .c else .none);

    next(self);
    //print("handler for band_abs8\n", .{});
    //insn.display();
}
fn handle_bclr_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const r = m & ~(@as(u8,1) << oands.a);
    self.shl(oands.b, r);

    next(self);
    //print("handler for bclr_imm_rn\n", .{});
    //insn.display();
}
fn handle_bclr_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << oands.a);
    next(self);
    self.write8(a, r);

    //print("handler for bclr_imm_Mern\n", .{});
    //insn.display();
}
fn handle_bclr_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << oands.a);
    next(self);
    self.write8(a, r);

    //print("handler for bclr_imm_abs8\n", .{});
    //insn.display();
}
fn handle_bclr_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const r = m & ~(@as(u8,1) << (@truncate(u3,self.ghl(oands.a)) & 7));
    self.shl(oands.b, r);

    next(self);
    //print("handler for bclr_rn_rn\n", .{});
    //insn.display();
}
fn handle_bclr_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << (@truncate(u3,self.ghl(oands.a)) & 7));
    next(self);
    self.write8(a, r);

    //print("handler for bclr_rn_Mern\n", .{});
    //insn.display();
}
fn handle_bclr_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << (@truncate(u3,self.ghl(oands.a)) & 7));
    next(self);
    self.write8(a, r);

    //print("handler for bclr_rn_abs8\n", .{});
    //insn.display();
}
fn handle_biand_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r == 0) .c else .none);

    next(self);
    //print("handler for biand_rn\n", .{});
    //insn.display();
}
fn handle_biand_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r == 0) .c else .none);

    next(self);
    //print("handler for biand_Mern\n", .{});
    //insn.display();
}
fn handle_biand_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r == 0) .c else .none);

    next(self);
    //print("handler for biand_abs8\n", .{});
    //insn.display();
}
fn handle_bild_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (r == 0) .c else .none);

    next(self);
    //print("handler for bild_rn\n", .{});
    //insn.display();
}
fn handle_bild_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (r == 0) .c else .none);

    next(self);
    //print("handler for bild_Mern\n", .{});
    //insn.display();
}
fn handle_bild_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (r == 0) .c else .none);

    next(self);
    //print("handler for bild_abs8\n", .{});
    //insn.display();
}
fn handle_bior_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r == 0) .c else .none);

    next(self);
    //print("handler for bior_rn\n", .{});
    //insn.display();
}
fn handle_bior_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r == 0) .c else .none);

    next(self);
    //print("handler for bior_Mern\n", .{});
    //insn.display();
}
fn handle_bior_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r == 0) .c else .none);

    next(self);
    //print("handler for bior_abs8\n", .{});
    //insn.display();
}
fn handle_bist_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, @boolToInt(!self.hasc(.c))) << oands.a);
    self.shl(oands.b, v);

    next(self);
    //print("handler for bist_rn\n", .{});
    //insn.display();
}
fn handle_bist_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, @boolToInt(!self.hasc(.c))) << oands.a);

    next(self);

    self.write8(a, v);

    //print("handler for bist_Mern\n", .{});
    //insn.display();
}
fn handle_bist_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, @boolToInt(!self.hasc(.c))) << oands.a);

    next(self);

    self.write8(a, v);

    //print("handler for bist_abs8\n", .{});
    //insn.display();
}
fn handle_bixor_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if ((@boolToInt(self.hasc(.c)) ^ @boolToInt(r == 0)) != 0) .c else .none);

    next(self);
    //print("handler for bixor_rn\n", .{});
    //insn.display();
}
fn handle_bixor_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if ((@boolToInt(self.hasc(.c)) ^ @boolToInt(r == 0)) != 0) .c else .none);

    next(self);
    //print("handler for bixor_Mern\n", .{});
    //insn.display();
}
fn handle_bixor_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if ((@boolToInt(self.hasc(.c)) ^ @boolToInt(r == 0)) != 0) .c else .none);

    next(self);
    //print("handler for bixor_abs8\n", .{});
    //insn.display();
}
fn handle_bld_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (r != 0) .c else .none);

    next(self);
    //print("handler for bld_rn\n", .{});
    //insn.display();
}
fn handle_bld_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (r != 0) .c else .none);

    next(self);
    //print("handler for bld_Mern\n", .{});
    //insn.display();
}
fn handle_bld_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (r != 0) .c else .none);

    next(self);
    //print("handler for bld_abs8\n", .{});
    //insn.display();
}
fn handle_bnot_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = m ^ (@as(u8,1) << oands.a);
    self.shl(oands.b, v);

    next(self);
    //print("handler for bnot_imm_rn\n", .{});
    //insn.display();
}
fn handle_bnot_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = m ^ (@as(u8,1) << oands.a);
    next(self);
    self.write8(a, v);

    //print("handler for bnot_imm_Mern\n", .{});
    //insn.display();
}
fn handle_bnot_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = m ^ (@as(u8,1) << oands.a);
    next(self);
    self.write8(a, v);

    //print("handler for bnot_imm_abs8\n", .{});
    //insn.display();
}
fn handle_bnot_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = m ^ (@as(u8,1) << @truncate(u3,self.ghl(oands.a)));
    self.shl(oands.b, v);

    next(self);
    //print("handler for bnot_rn_rn\n", .{});
    //insn.display();
}
fn handle_bnot_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = m ^ (@as(u8,1) << @truncate(u3,self.ghl(oands.a)));
    next(self);
    self.write8(a, v);

    //print("handler for bnot_rn_Mern\n", .{});
    //insn.display();
}
fn handle_bnot_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = m ^ (@as(u8,1) << @truncate(u3,self.ghl(oands.a)));
    next(self);
    self.write8(a, v);

    //print("handler for bnot_rn_abs8\n", .{});
    //insn.display();
}
fn handle_bor_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r != 0) .c else .none);

    next(self);
    //print("handler for bor_rn\n", .{});
    //insn.display();
}
fn handle_bor_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r != 0) .c else .none);

    next(self);
    //print("handler for bor_Mern\n", .{});
    //insn.display();
}
fn handle_bor_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const m = self.read8(@as(u16, oands.b) | 0xff00);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r != 0) .c else .none);

    next(self);
    //print("handler for bor_abs8\n", .{});
    //insn.display();
}
fn handle_bset_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, 1) << oands.a);
    self.shl(oands.b, v);

    next(self);
    //print("handler for bset_imm_rn\n", .{});
    //insn.display();
}
fn handle_bset_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, 1) << oands.a);

    next(self);

    self.write8(a, v);

    //print("handler for bset_imm_Mern\n", .{});
    //insn.display();
}
fn handle_bset_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, 1) << oands.a);

    next(self);

    self.write8(a, v);

    //print("handler for bset_imm_abs8\n", .{});
    //insn.display();
}
fn handle_bset_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = (m & ~(@as(u8,1) << @truncate(u3,self.ghl(oands.a))))
            | (@as(u8, 1) << @truncate(u3,self.ghl(oands.a)));
    self.shl(oands.b, v);

    next(self);
    //print("handler for bset_rn_rn\n", .{});
    //insn.display();
}
fn handle_bset_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << @truncate(u3,self.ghl(oands.a))))
            | (@as(u8, 1) << @truncate(u3,self.ghl(oands.a)));

    next(self);

    self.write8(a, v);

    //print("handler for bset_rn_Mern\n", .{});
    //insn.display();
}
fn handle_bset_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << @truncate(u3,self.ghl(oands.a))))
            | (@as(u8, 1) << @truncate(u3,self.ghl(oands.a)));

    next(self);

    self.write8(a, v);

    //print("handler for bset_rn_abs8\n", .{});
    //insn.display();
}
fn handle_bst_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, @boolToInt(self.hasc(.c))) << oands.a);
    self.shl(oands.b, v);

    next(self);
    //print("handler for bst_rn\n", .{});
    //insn.display();
}
fn handle_bst_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, @boolToInt(self.hasc(.c))) << oands.a);

    next(self);

    self.write8(a, v);

    //print("handler for bst_Mern\n", .{});
    //insn.display();
}
fn handle_bst_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, @boolToInt(self.hasc(.c))) << oands.a);

    next(self);

    self.write8(a, v);

    //print("handler for bst_abs8\n", .{});
    //insn.display();
}
fn handle_btst_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = (m & (@as(u8,1) << oands.a));
    self.setc(.z, if (v == 0) .z else .none);

    next(self);
    //print("handler for btst_imm_rn\n", .{});
    //insn.display();
}
fn handle_btst_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = (m & (@as(u8,1) << oands.a));
    self.setc(.z, if (v == 0) .z else .none);

    next(self);
    //print("handler for btst_imm_Mern\n", .{});
    //insn.display();
}
fn handle_btst_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = (m & (@as(u8,1) << oands.a));
    self.setc(.z, if (v == 0) .z else .none);

    next(self);
    //print("handler for btst_imm_abs8\n", .{});
    //insn.display();
}
fn handle_btst_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const v = (m & (@as(u8,1) << @truncate(u3,self.ghl(oands.a))));
    self.setc(.z, if (v == 0) .z else .none);

    next(self);
    //print("handler for btst_rn_rn\n", .{});
    //insn.display();
}
fn handle_btst_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const v = (m & (@as(u8,1) << @truncate(u3,self.ghl(oands.a))));
    self.setc(.z, if (v == 0) .z else .none);

    next(self);
    //print("handler for btst_rn_Mern\n", .{});
    //insn.display();
}
fn handle_btst_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const v = (m & (@as(u8,1) << @truncate(u3,self.ghl(oands.a))));
    self.setc(.z, if (v == 0) .z else .none);

    next(self);
    //print("handler for btst_rn_abs8\n", .{});
    //insn.display();
}
fn handle_bxor_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if ((@boolToInt(self.hasc(.c)) ^ @boolToInt(r != 0)) != 0) .c else .none);

    next(self);
    //print("handler for bxor_rn\n", .{});
    //insn.display();
}
fn handle_bxor_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if ((@boolToInt(self.hasc(.c)) ^ @boolToInt(r != 0)) != 0) .c else .none);

    next(self);
    //print("handler for bxor_Mern\n", .{});
    //insn.display();
}
fn handle_bxor_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = 0xff00 | @as(u16,oands.b);
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if ((@boolToInt(self.hasc(.c)) ^ @boolToInt(r != 0)) != 0) .c else .none);

    next(self);
    //print("handler for bxor_abs8\n", .{});
    //insn.display();
}
fn handle_cmp_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = b -% a;
    flg_arith(u8, self, a, b, r, false, .sub);

    next(self);
    //print("handler for cmp_b_imm\n", .{});
    //insn.display();
}
fn handle_cmp_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = b -% a;
    flg_arith(u16, self, a, b, r, false, .sub);

    next(self);
    //print("handler for cmp_w_imm\n", .{});
    //insn.display();
}
fn handle_cmp_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = b -% a;
    flg_arith(u32, self, a, b, r, false, .sub);

    next(self);
    //print("handler for cmp_l_imm\n", .{});
    //insn.display();
}
fn handle_cmp_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = b -% a;
    flg_arith(u8, self, a, b, r, false, .sub);

    next(self);
    //print("handler for cmp_b_rn\n", .{});
    //insn.display();
}
fn handle_cmp_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = b -% a;
    flg_arith(u16, self, a, b, r, false, .sub);

    next(self);
    //print("handler for cmp_w_rn\n", .{});
    //insn.display();
}
fn handle_cmp_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = b -% a;
    self.ser(oands.b, r);
    flg_arith(u32, self, a, b, r, false, .sub);

    next(self);
    //print("handler for cmp_l_rn\n", .{});
    //insn.display();
}
fn handle_daa(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.ghl(oands);
    const hi = (v >> 4) & 0xf;
    const lo = v & 0xf;

    const c = self.hasc(.c);
    const h = self.hasc(.h);
    const addv: u8 = blk: {
        if (!c) {
            if (!h) {
                if (hi <= 9 and lo <= 9) break :blk 0x00;
                if (hi <= 8 and lo >= 0xa) break :blk 0x06;
                if (hi >= 0xa and lo <= 9) break :blk 0x60;
                if (hi >= 9 and lo >= 0xa) break :blk 0x66;
            } else {
                if (hi <= 9 and lo <= 3) break :blk 0x06;
                if (hi >= 0xa and lo <= 3) break :blk 0x66;
            }
        } else {
            if (!h) {
                if ((hi == 1 or hi == 2) and lo <= 9) break :blk 0x60;
                if ((hi == 1 or hi == 2) and lo >= 0xa) break :blk 0x66;
            } else {
                if (hi >= 1 and hi <= 3 and lo <= 3) break :blk 0x66;
            }
        }

        print("W: daa with undefined result!\n", .{});
        break :blk undefined;
    };

    const res = v +% addv;
    self.shl(oands, res);
    self.setc(.c, if ((addv & 0x60) == 0x60) .c else .none);
    self.setc(.z, if (res == 0) .z else .none);
    self.setc(.n, if ((res  & 0x80) == 0x80) .n else .none);
    //self.setc(.h, undefined); // TODO: bleh
    //self.setc(.v, undefined);

    next(self);
    //print("handler for daa\n", .{});
    //insn.display();
}
fn handle_das(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.ghl(oands);
    const hi = (v >> 4) & 0xf;
    const lo = v & 0xf;

    const c = self.hasc(.c);
    const h = self.hasc(.h);
    const addv: u8 = blk: {
        if (!c) {
            if (!h) {
                if (hi <= 9 and lo <= 9) break :blk 0x00;
            } else {
                if (hi <= 8 and lo >= 6) break :blk 0xfa;
            }
        } else {
            if (!h) {
                if (hi >= 7 and lo <= 9) break :blk 0xa0;
            } else {
                if (hi >= 6 and lo >= 6) break :blk 0x9a;
            }
        }

        print("W: das with undefined result!\n", .{});
        break :blk undefined;
    };

    const res = v +% addv;
    self.shl(oands, res);
    self.setc(.z, if (res == 0) .z else .none);
    self.setc(.n, if ((res  & 0x80) == 0x80) .n else .none);
    //self.setc(.h, undefined); // TODO: bleh
    //self.setc(.v, undefined);

    next(self);
    //print("handler for das\n", .{});
    //insn.display();
}
fn handle_dec_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.ghl(oands);
    const r = v -% 1;
    self.shl(oands, r);
    flg_logic(u8, self, r);
    self.setc(.v, if (v == 0x80) .v else .none);

    next(self);
    //print("handler for dec_b\n", .{});
    //insn.display();
}
fn handle_dec_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.grn(oands.b);
    const r = v -% oands.a.val();
    self.srn(oands.b, r);
    flg_logic(u16, self, r);
    self.setc(.v, if (v == 0x8000 or (v == 0x8001 and oands.a == .two)) .v else .none);

    next(self);
    //print("handler for dec_w\n", .{});
    //insn.display();
}
fn handle_dec_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.ger(oands.b);
    const r = v -% oands.a.val();
    self.ser(oands.b, r);
    flg_logic(u32, self, r);
    self.setc(.v, if (v == 0x80000000 or (v == 0x80000001 and oands.a == .two)) .v else .none);

    next(self);
    //print("handler for dec_l\n", .{});
    //insn.display();
}
fn handle_divxs_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.grn(oands.b);

    if (a == 0) {
        self.setc(.z, .z);
    } else {
        const div = @truncate(u8, @bitCast(u16, @divExact(@bitCast(i16,b), @bitCast(i8,a))));
        const rem = @truncate(u8, @bitCast(u16, @mod(@bitCast(i16,b), @bitCast(i8,a))));

        self.srn(oands.b, (@as(u16,rem) << 8) | div);
        self.setc(.n, if (((a ^ (b>>8)) & 0x80) != 0) .n else .none);
    }

    next(self);
    self.cycle(12);

    //print("handler for divxs_b\n", .{});
    //insn.display();
}
fn handle_divxs_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.ger(oands.b);

    if (a == 0) {
        self.setc(.z, .z);
    } else {
        const div = @truncate(u16, @bitCast(u32, @divExact(@bitCast(i32,b), @bitCast(i16,a))));
        const rem = @truncate(u16, @bitCast(u32, @mod(@bitCast(i32,b), @bitCast(i16,a))));

        self.ser(oands.b, (@as(u32,rem) << 16) | div);
        self.setc(.n, if (((a ^ (b>>16)) & 0x8000) != 0) .n else .none);
    }

    next(self);
    self.cycle(20);

    //print("handler for divxs_w\n", .{});
    //insn.display();
}
fn handle_divxu_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.grn(oands.b);

    if (a == 0) {
        self.setc(.z, .z);
    } else {
        const div = b / a;
        const rem = b % a;

        self.srn(oands.b, (@as(u16,rem) << 8) | div);
        self.setc(.n, if (((a ^ (b>>8)) & 0x80) != 0) .n else .none);
    }

    next(self);
    self.cycle(12);

    //print("handler for divxu_b\n", .{});
    //insn.display();
}
fn handle_divxu_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.ger(oands.b);

    if (a == 0) {
        self.setc(.z, .z);
    } else {
        const div = b / a;
        const rem = b % a;

        self.ser(oands.b, (@as(u32,rem) << 16) | div);
        self.setc(.n, if (((a ^ (b>>16)) & 0x8000) != 0) .n else .none);
    }

    next(self);
    self.cycle(20);

    //print("handler for divxu_w\n", .{});
    //insn.display();
}
fn handle_eepmov_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    // eas = er5, ead = r6
    // 2: ++er5, r6; n=r4l/r4; only rw/inc if n!=0
    var eas = self.ger(.er5);
    var ead = self.ger(.er6);
    var n = self.ghl(.r4l);

    // for some reason, this happens
    _ = self.read8(@truncate(u16, eas));
    _ = self.read8(@truncate(u16, ead));

    while (n != 0) : (n -= 1) {
        const v = self.read8(@truncate(u16, eas));
        self.write8(@truncate(u16, ead), v);

        eas += 1;
        ead += 1;
    }

    self.ser(.er5, eas);
    self.ser(.er6, ead);
    self.shl(.r4l, n);

    next(self);
    //print("handler for eepmov_b\n", .{});
    //insn.display();
}
fn handle_eepmov_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    // eas = er5, ead = r6
    // 2: ++er5, r6; n=r4l/r4; only rw/inc if n!=0
    var eas = self.ger(.er5);
    var ead = self.ger(.er6);
    var n = self.grn(.r4);

    // for some reason, this happens
    _ = self.read8(@truncate(u16, eas));
    _ = self.read8(@truncate(u16, ead));

    while (n != 0) : (n -= 1) {
        // TODO: check for pending NMI, switch if needed (eepmov.b doesn't have this)
        const v = self.read8(@truncate(u16, eas));
        self.write8(@truncate(u16, ead), v);

        eas += 1;
        ead += 1;
    }

    self.ser(.er5, eas);
    self.ser(.er6, ead);
    self.srn(.r4, n);

    next(self);
    //print("handler for eepmov_w\n", .{});
    //insn.display();
}
fn handle_exts_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const x = self.grn(oands);
    const bit = @truncate(u1, (x & 0x80) >> 7);
    const v = (x & 0xff) | (0xff00 * @as(u16,bit));
    self.srn(oands, v);
    flg_logic(u16, self, v);
    self.setc(.v, .none);

    next(self);
    //print("handler for exts_w\n", .{});
    //insn.display();
}
fn handle_exts_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const x = self.ger(oands);
    const bit = @truncate(u1, (x & 0x8000) >> 15);
    const v = (x & 0xffff) | (0xffff0000 * @as(u32,bit));
    self.ser(oands, v);
    flg_logic(u32, self, v);
    self.setc(.v, .none);

    next(self);
    //print("handler for exts_l\n", .{});
    //insn.display();
}
fn handle_extu_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const x = self.grn(oands);
    const v = (x & 0xff);
    self.srn(oands, v);
    self.andc(@intToEnum(CCR, 0xd0|36)); // i, u, ui, h, c
    if (v == 0) self.orc(.z);

    next(self);
    //print("handler for extu_w\n", .{});
    //insn.display();
}
fn handle_extu_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const x = self.ger(oands);
    const v = (x & 0xff);
    self.ser(oands, v);
    self.andc(@intToEnum(CCR, 0xd0|36)); // i, u, ui, h, c
    if (v == 0) self.orc(.z);

    next(self);
    //print("handler for extu_l\n", .{});
    //insn.display();
}
fn handle_inc_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.ghl(oands);
    const r = v +% 1;
    self.shl(oands, r);
    flg_logic(u8, self, r);
    self.setc(.v, if (v == 0x7f) .v else .none);

    next(self);
    //print("handler for inc_b\n", .{});
    //insn.display();
}
fn handle_inc_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.grn(oands.b);
    const r = v +% oands.a.val();
    self.srn(oands.b, r);
    flg_logic(u16, self, r);
    self.setc(.v, if (v == 0x7fff or (v == 0x7ffe and oands.a == .two)) .v else .none);

    next(self);
    //print("handler for inc_w\n", .{});
    //insn.display();
}
fn handle_inc_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const v = self.ger(oands.b);
    const r = v +% oands.a.val();
    self.ser(oands.b, r);
    flg_logic(u32, self, r);
    self.setc(.v, if (v == 0x7fffffff or (v == 0x7ffffffe and oands.a == .two)) .v else .none);

    next(self);
    //print("handler for inc_l\n", .{});
    //insn.display();
}
fn handle_jmp_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const m = @truncate(u16, self.ger(oands));
    const a = m;//self.read16(m); // TODO: which of the two?
    self.pc = a;
    next(self); // TODO: required here, though kinda off-spec... IF doing PC=Mem[ERn]! OK if PC=ERn

    //print("handler for jmp_Mern\n", .{});
    //insn.display();
    //@panic("checkme");
}
fn handle_jmp_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    self.cycle(2);

    const m = @truncate(u16, oands);
    const a = m;//self.read16(m); // TODO: is this a direct immediate, or indirect?
    self.pc = a;
    next(self);

    //print("handler for jmp_abs24\n", .{});
    //insn.display();
    //@panic("checkme");
}
fn handle_jmp_MMabs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const m = @as(u16, oands);
    const a = self.read16(m);

    self.cycle(2);

    self.pc = a;
    next(self);

    //print("handler for jmp_MMabs8\n", .{});
    //insn.display();
}
fn handle_jsr_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const p = self.pc;
    next(self);

    // pc -> @-sp
    // EA -> pc
    const m = @truncate(u16, self.ger(oands));
    const a = m;//self.read16(m); // TODO: which of the two?
    self.pc = a;
    next(self); // TODO: required here, though kinda off-spec... IF doing PC=Mem[ERn]! OK if PC=ERn

    const s = self.gsp() -% 2;
    self.ssp(s);
    self.write16(s, p);
    print("jsr Mern: pc=0x{x:}, sp=0x{x:}\n", .{a, s});

    //print("handler for jsr_Mern\n", .{});
    insn.display();
    self.stat();
    @panic("checkme");
}
fn handle_jsr_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    self.cycle(2);

    // pc -> @-sp
    // EA -> pc
    const p = self.pc;
    const m = @truncate(u16, oands);
    const a = m;//self.read16(m); // TODO: is this a direct immediate, or indirect?
    const s = self.gsp() -% 2;

    print("jsr abs24: pc=0x{x:}, sp=0x{x:}\n", .{a, s});
    self.stat();

    self.pc = a;
    next(self);

    self.ssp(s);
    self.write16(s, p);
    //print("handler for jsr_abs24\n", .{});
    //insn.display();
    //@panic("checkme");
}
fn handle_jsr_MMabs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const p = self.pc;
    next(self);

    const m = @as(u16, oands);
    const a = self.read16(m);

    const s = self.gsp() -% 2;
    self.ssp(s);
    self.write16(s, p);
    print("jsr MMabs8: pc=0x{x:}, sp=0x{x:}\n", .{p, s});

    self.pc = a;
    next(self);

    //print("handler for jsr_MMabs8\n", .{});
    insn.display();
    self.stat();
    @panic("checkme");
}
fn handle_ldc_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    self.ccr = @intToEnum(CCR, oands);

    next(self);
    //print("handler for ldc_b_imm\n", .{});
    //insn.display();
}
fn handle_ldc_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    self.ccr = @intToEnum(CCR, self.ghl(oands));

    next(self);
    //print("handler for ldc_b_rn\n", .{});
    //insn.display();
}
fn handle_ldc_w_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = self.read16(@truncate(u16, self.ger(oands)));
    self.ccr = @intToEnum(CCR, @truncate(u8, v));

    //print("handler for ldc_w_Mern\n", .{});
    //insn.display();
}
fn handle_ldc_w_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = self.read16(oands.a +% @truncate(u16, self.ger(oands.b)));
    self.ccr = @intToEnum(CCR, @truncate(u8, v));

    //print("handler for ldc_w_d16\n", .{});
    //insn.display();
}
fn handle_ldc_w_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = self.read16(@truncate(u16, @as(u32, oands.a) +% self.ger(oands.b)));
    self.ccr = @intToEnum(CCR, @truncate(u8, v));

    //print("handler for ldc_w_d24\n", .{});
    //insn.display();
}
fn handle_ldc_w_Mern_inc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = self.read16(@truncate(u16, self.ger(oands)));
    self.ccr = @intToEnum(CCR, @truncate(u8, v));

    self.cycle(2);
    self.ser(oands, self.ger(oands) +% 2);

    //print("handler for ldc_w_Mern_inc\n", .{});
    //insn.display();
}
fn handle_ldc_w_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = self.read16(oands);
    self.ccr = @intToEnum(CCR, @truncate(u8, v));

    //print("handler for ldc_w_abs16\n", .{});
    //insn.display();
}
fn handle_ldc_w_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = self.read16(@truncate(u16, oands));
    self.ccr = @intToEnum(CCR, @truncate(u8, v));

    //print("handler for ldc_w_abs24\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const v = self.ghl(oands.a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const v = self.grn(oands.a);
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_rn_rn\n", .{});
    //insn.display();
    //self.stat();
}
fn handle_mov_l_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const v = self.ger(oands.a);
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_rn_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const v = oands.a;
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_imm_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = oands.a;
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_imm_rn\n", .{});
    //insn.display();
}
fn handle_mov_l_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = oands.a;
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_imm_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_Mern_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @truncate(u16,self.ger(oands.a));
    const v = self.read8(a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_Mern_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_Mern_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @truncate(u16,self.ger(oands.a));
    const v = self.read16(a);
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_Mern_rn\n", .{});
    //insn.display();
}
fn handle_mov_l_Mern_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a));
    const v1 = self.read16(a   );
    const v2 = self.read16(a+%2);
    const v = (@as(u32,v1)<<16)|@as(u32,v2);
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_Mern_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_d16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a2)) +% oands.a1;
    const v = self.read8(a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_d16_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_d16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a2)) +% oands.a1;
    const v = self.read16(a);
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_d16_rn\n", .{});
    //insn.display();
}
fn handle_mov_l_d16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a2)) +% oands.a1;
    const v1 = self.read16(a   );
    const v2 = self.read16(a+%2);
    const v = (@as(u32,v1)<<16)|@as(u32,v2);
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_d16_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_d24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a2)) +% @truncate(u16,oands.a1);
    const v = self.read8(a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_d24_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_d24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a2)) +% @truncate(u16,oands.a1);
    const v = self.read8(a);
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_d24_rn\n", .{});
    //insn.display();
}
fn handle_mov_l_d24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a2)) +% @truncate(u16,oands.a1);
    const v1 = self.read16(a   );
    const v2 = self.read16(a+%2);
    const v = (@as(u32,v1)<<16)|@as(u32,v2);
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_d24_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_Mern_inc_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @truncate(u16,self.ger(oands.a));
    self.ser(oands.a, self.ger(oands.a) +% 1);
    self.cycle(2);

    const v = self.read8(a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_Mern_inc_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_Mern_inc_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @truncate(u16,self.ger(oands.a));
    self.ser(oands.a, self.ger(oands.a) +% 2);
    self.cycle(2);

    const v = self.read16(a);
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_Mern_inc_rn\n", .{});
    //insn.display();
}
fn handle_mov_l_Mern_inc_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,self.ger(oands.a));
    self.ser(oands.a, self.ger(oands.a) +% 4);
    self.cycle(2);

    const v1 = self.read16(a   );
    const v2 = self.read16(a+%2);
    const v = (@as(u32,v1)<<16)|@as(u32,v2);
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_Mern_inc_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_abs8_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @as(u16, oands.a) | 0xff00;
    const v = self.read8(a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_abs8_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_abs16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = oands.a;
    const v = self.read8(a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_abs16_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_abs16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = oands.a;
    const v = self.read16(a);
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_abs16_rn\n", .{});
    //insn.display();
}
fn handle_mov_l_abs16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = oands.a;
    const v1 = self.read16(a   );
    const v2 = self.read16(a+%2);
    const v = (@as(u32,v1)<<16)|@as(u32,v2);
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_abs16_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_abs24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,oands.a);
    const v = self.read8(a);
    self.shl(oands.b, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_abs24_rn\n", .{});
    //insn.display();
}
fn handle_mov_w_abs24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,oands.a);
    const v = self.read16(a);
    self.srn(oands.b, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_abs24_rn\n", .{});
    //insn.display();
}
fn handle_mov_l_abs24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16,oands.a);
    const v1 = self.read16(a   );
    const v2 = self.read16(a+%2);
    const v = (@as(u32,v1)<<16)|@as(u32,v2);
    self.ser(oands.b, v);
    flg_mov(u32, self, v);

    //print("handler for mov_l_abs24_rn\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @truncate(u16, self.ger(oands.b));
    const v = self.ghl(oands.a);
    self.write8(a, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_Mern\n", .{});
    //insn.display();
}
fn handle_mov_w_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @truncate(u16, self.ger(oands.b));
    const v = self.grn(oands.a);
    self.write16(a, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_rn_Mern\n", .{});
    //insn.display();
}
fn handle_mov_l_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, self.ger(oands.b));
    const v = self.ger(oands.a);
    self.write16(a   , @truncate(u16, v >> 16));
    self.write16(a+%2, @truncate(u16, v >>  0));
    flg_mov(u32, self, v);

    //print("handler for mov_l_rn_Mern\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, self.ger(oands.b2)) +% oands.b1;
    const v = self.ghl(oands.a);
    self.write8(a, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_d16\n", .{});
    //insn.display();
}
fn handle_mov_w_rn_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, self.ger(oands.b2)) +% oands.b1;
    const v = self.grn(oands.a);
    self.write16(a, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_rn_d16\n", .{});
    //insn.display();
}
fn handle_mov_l_rn_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, self.ger(oands.b2)) +% oands.b1;
    const v = self.ger(oands.a);
    self.write16(a   , @truncate(u16, v >> 16));
    self.write16(a+%2, @truncate(u16, v >>  0));
    flg_mov(u32, self, v);

    //print("handler for mov_l_rn_d16\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, self.ger(oands.b2)) +% @truncate(u16,oands.b1);
    const v = self.ghl(oands.a);
    self.write8(a, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_d24\n", .{});
    //insn.display();
}
fn handle_mov_w_rn_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, self.ger(oands.b2)) +% @truncate(u16,oands.b1);
    const v = self.grn(oands.a);
    self.write16(a, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_rn_d24\n", .{});
    //insn.display();
}
fn handle_mov_l_rn_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, self.ger(oands.b2)) +% @truncate(u16,oands.b1);
    const v = self.ger(oands.a);
    self.write16(a   , @truncate(u16, v >> 16));
    self.write16(a+%2, @truncate(u16, v >>  0));
    flg_mov(u32, self, v);

    //print("handler for mov_l_rn_d24\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const aa=self.ger(oands.b) -% 1;
    const a = @truncate(u16, aa);
    self.ser(oands.b, aa);
    self.cycle(2);

    const v = self.ghl(oands.a);
    self.write8(a, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_Mern_dec\n", .{});
    //insn.display();
}
fn handle_mov_w_rn_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    next(self);

    const aa=self.ger(oands.b) -% 2;
    const a = @truncate(u16, aa);
    self.ser(oands.b, aa);
    self.cycle(2);

    const v = self.grn(oands.a);
    self.write16(a, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_rn_Mern_dec\n", .{});
    //insn.display();
}
fn handle_mov_l_rn_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const aa=self.ger(oands.b) -% 4;
    const a = @truncate(u16, aa);
    self.ser(oands.b, aa);
    self.cycle(2);

    const v = self.ger(oands.a);
    self.write16(a   , @truncate(u16, v >> 16));
    self.write16(a+%2, @truncate(u16, v >>  0));
    flg_mov(u32, self, v);

    //print("handler for mov_l_rn_Mern_dec\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = @as(u16, oands.b) | 0xff00;
    const v = self.ghl(oands.a);
    self.write8(a, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_abs8\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = oands.b;
    const v = self.ghl(oands.a);
    self.write8(a, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_abs16\n", .{});
    //insn.display();
}
fn handle_mov_w_rn_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = oands.b;
    const v = self.grn(oands.a);
    self.write16(a, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_rn_abs16\n", .{});
    //insn.display();
}
fn handle_mov_l_rn_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = oands.b;
    const v = self.ger(oands.a);
    self.write16(a   , @truncate(u16, v >> 16));
    self.write16(a+%2, @truncate(u16, v >>  0));
    flg_mov(u32, self, v);

    //print("handler for mov_l_rn_abs16\n", .{});
    //insn.display();
}
fn handle_mov_b_rn_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, oands.b);
    const v = self.ghl(oands.a);
    self.write8(a, v);
    flg_mov(u8, self, v);

    //print("handler for mov_b_rn_abs24\n", .{});
    //insn.display();
}
fn handle_mov_w_rn_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, oands.b);
    const v = self.grn(oands.a);
    self.write16(a, v);
    flg_mov(u16, self, v);

    //print("handler for mov_w_rn_abs24\n", .{});
    //insn.display();
}
fn handle_mov_l_rn_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = @truncate(u16, oands.b);
    const v = self.ger(oands.a);
    self.write16(a   , @truncate(u16, v >> 16));
    self.write16(a+%2, @truncate(u16, v >>  0));
    flg_mov(u32, self, v);

    //print("handler for mov_l_rn_abs24\n", .{});
    //insn.display();
}
fn handle_movfpe(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //print("handler for movfpe\n", .{});
    //insn.display();
    @panic("not implemented!");
}
fn handle_movtpe(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //print("handler for movtpe\n", .{});
    //insn.display();
    @panic("not implemented!");
}
fn handle_mulxs_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = self.ghl(oands.a); // rs
    const b = self.grn(oands.b); // rd

    const prod = @as(i16,@bitCast(i8, @truncate(u8, b))) * @as(i16,@bitCast(i8, a));

    self.srn(oands.b, @bitCast(u16, prod));
    self.setc(.n, if (prod <  0) .n else .none);
    self.setc(.z, if (prod == 0) .z else .none);

    self.cycle(12);

    //print("handler for mulxs_b\n", .{});
    //insn.display();
}
fn handle_mulxs_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const a = self.grn(oands.a); // rs
    const b = self.ger(oands.b); // rd

    const prod = @as(i32,@bitCast(i16,@truncate(u16,b))) * @as(i32,@bitCast(i16,a));

    self.ser(oands.b, @bitCast(u32, prod));
    self.setc(.n, if (prod <  0) .n else .none);
    self.setc(.z, if (prod == 0) .z else .none);

    self.cycle(20);

    //print("handler for mulxs_w\n", .{});
    //insn.display();
}
fn handle_mulxu_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands.a); // rs
    const b = self.grn(oands.b); // rd

    const prod = @as(u16, @as(u16,@truncate(u8, b)) * @as(u16, a));

    self.srn(oands.b, prod);

    self.cycle(12);

    //print("handler for mulxu_b\n", .{});
    //insn.display();
}
fn handle_mulxu_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands.a); // rs
    const b = self.ger(oands.b); // rd

    const prod = @as(u32, @as(u32,@truncate(u16, b)) * @as(u32, a));

    self.ser(oands.b, prod);

    //print("handler for mulxu_w\n", .{});
    //insn.display();
}
fn handle_neg_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const n = ~a +% 1;

    flg_arith(u8, self, a, 0, n, false, .neg);
    self.shl(oands, n);

    //print("handler for neg_b\n", .{});
    //insn.display();
}
fn handle_neg_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const n = ~a +% 1;

    flg_arith(u16, self, a, 0, n, false, .neg);
    self.srn(oands, n);

    //print("handler for neg_w\n", .{});
    //insn.display();
}
fn handle_neg_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const n = ~a +% 1;

    flg_arith(u32, self, a, 0, n, false, .neg);
    self.ser(oands, n);

    //print("handler for neg_l\n", .{});
    //insn.display();
}
fn handle_nop(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    //print("handler for nop\n", .{});
    //insn.display();
}
fn handle_not_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const n = ~a;

    flg_logic(u8, self, n);
    self.shl(oands, n);

    //print("handler for not_b\n", .{});
    //insn.display();
}
fn handle_not_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const n = ~a;

    flg_logic(u16, self, n);
    self.srn(oands, n);

    //print("handler for not_w\n", .{});
    //insn.display();
}
fn handle_not_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const n = ~a;

    flg_logic(u32, self, n);
    self.ser(oands, n);

    //print("handler for not_l\n", .{});
    //insn.display();
}
fn handle_or_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a | b;
    self.shl(oands.b, r);
    flg_logic(u8, self, r);

    next(self);

    //print("handler for or_b_imm\n", .{});
    //insn.display();
}
fn handle_or_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = a | b;
    self.srn(oands.b, r);
    flg_logic(u16, self, r);

    next(self);

    //print("handler for or_w_imm\n", .{});
    //insn.display();
}
fn handle_or_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = a | b;
    self.ser(oands.b, r);
    flg_logic(u32, self, r);

    next(self);

    //print("handler for or_l_imm\n", .{});
    //insn.display();
}
fn handle_or_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a | b;
    self.shl(oands.b, r);
    flg_logic(u8, self, r);

    next(self);

    //print("handler for or_b_rn\n", .{});
    //insn.display();
}
fn handle_or_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = a | b;
    self.srn(oands.b, r);
    flg_logic(u16, self, r);

    next(self);

    //print("handler for or_w_rn\n", .{});
    //insn.display();
}
fn handle_or_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = a | b;
    self.ser(oands.b, r);
    flg_logic(u32, self, r);

    next(self);

    //print("handler for or_l_rn\n", .{});
    //insn.display();
}
fn handle_orc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    self.orc(@intToEnum(CCR, oands));

    next(self);

    //print("handler for orc\n", .{});
    //insn.display();
}
fn handle_rotl_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = (a << 1) | ((a & 0x80) >> 7);
    self.shl(oands, @truncate(u8,b));
    flg_shro(u8, self, a, b, (a&0x80)!=0);

    //print("handler for rotl_b\n", .{});
    //insn.display();
}
fn handle_rotl_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = (a << 1) | ((a & 0x8000) >> 15);
    self.srn(oands, @truncate(u16,b));
    flg_shro(u16, self, a, b, (a&0x8000)!=0);

    //print("handler for rotl_w\n", .{});
    //insn.display();
}
fn handle_rotl_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = (a << 1) | ((a & 0x80000000) >> 31);
    self.ser(oands, @truncate(u32,b));
    flg_shro(u32, self, a, b, (a&0x80000000)!=0);

    //print("handler for rotl_l\n", .{});
    //insn.display();
}
fn handle_rotr_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = (a >> 1) | ((a & 1) << 7);
    self.shl(oands, b);
    flg_shro(u8, self, a, b, (a&1)!=0);

    //print("handler for rotr_b\n", .{});
    //insn.display();
}
fn handle_rotr_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = (a >> 1) | ((a & 1) << 15);
    self.srn(oands, b);
    flg_shro(u16, self, a, b, (a&1)!=0);

    //print("handler for rotr_w\n", .{});
    //insn.display();
}
fn handle_rotr_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = (a >> 1) | ((a & 1) << 31);
    self.ser(oands, b);
    flg_shro(u32, self, a, b, (a&1)!=0);

    //print("handler for rotr_l\n", .{});
    //insn.display();
}
fn handle_rotxl_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = (a << 1) | (if (self.hasc(.c)) @as(u8,1) else 0);
    self.shl(oands, @truncate(u8,b));
    flg_shro(u8, self, a, b, (a&0x80)!=0);

    //print("handler for rotxl_b\n", .{});
    //insn.display();
}
fn handle_rotxl_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = (a << 1) | (if (self.hasc(.c)) @as(u16,1) else 0);
    self.srn(oands, @truncate(u16,b));
    flg_shro(u16, self, a, b, (a&0x8000)!=0);

    //print("handler for rotxl_w\n", .{});
    //insn.display();
}
fn handle_rotxl_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = (a << 1) | (if (self.hasc(.c)) @as(u32,1) else 0);
    self.ser(oands, @truncate(u32,b));
    flg_shro(u32, self, a, b, (a&0x80000000)!=0);

    //print("handler for rotxl_l\n", .{});
    //insn.display();
}
fn handle_rotxr_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = (a >> 1) | (if (self.hasc(.c)) @as(u8,0x80) else 0);
    self.shl(oands, b);
    flg_shro(u8, self, a, b, (a&1)!=0);

    //print("handler for rotxr_b\n", .{});
    //insn.display();
}
fn handle_rotxr_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = (a >> 1) | (if (self.hasc(.c)) @as(u16,0x8000) else 0);
    self.srn(oands, b);
    flg_shro(u16, self, a, b, (a&1)!=0);

    //print("handler for rotxr_w\n", .{});
    //insn.display();
}
fn handle_rotxr_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = (a >> 1) | (if (self.hasc(.c)) @as(u32,0x80000000) else 0);
    self.ser(oands, b);
    flg_shro(u32, self, a, b, (a&1)!=0);

    //print("handler for rotxr_l\n", .{});
    //insn.display();
}
fn handle_rte(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    // @sp+ -> ccr
    // @sp+ -> pc
    const ccr = self.read16(self.gsp()     );
    const pc  = self.read16(self.gsp() +% 2);

    self.ssp(self.gsp() +% 4);
    self.pc  = pc;
    self.ccr = @intToEnum(CCR, @truncate(u8, ccr));
    self.cycle(2);

    next(self);

    //print("handler for rte\n", .{});
    //insn.display();
}
fn handle_rts(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    // @sp+ -> pc
    const sp = self.gsp();
    print("rts: sp at H'{x:4}\n", .{sp});
    const pc = self.read16(sp);
    print("rts: return to H'{x:4}\n", .{pc});
    self.stat();

    self.ssp(sp +% 2);
    self.pc  = pc;
    self.cycle(2);

    next(self);

    //print("handler for rts\n", .{});
    //insn.display();
}
fn handle_shal_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = a << 1;

    self.shl(oands, @truncate(u8, b));
    flg_shro(u8, self, a, b, (a&0x80)!=0);
    if ((((a & 0x80) >> 7) ^ ((a & 0x40) >> 6)) != 0) self.orc(.v);

    //print("handler for shal_b\n", .{});
    //insn.display();
}
fn handle_shal_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = a << 1;

    self.srn(oands, @truncate(u16, b));
    flg_shro(u16, self, a, b, (a&0x8000)!=0);
    if ((((a & 0x8000) >> 15) ^ ((a & 0x4000) >> 14)) != 0) self.orc(.v);

    //print("handler for shal_w\n", .{});
    //insn.display();
}
fn handle_shal_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = a << 1;

    self.ser(oands, @truncate(u32, b));
    flg_shro(u32, self, a, b, (a&0x80000000)!=0);
    if ((((a & 0x80000000) >> 31) ^ ((a & 0x40000000) >> 30)) != 0) self.orc(.v);

    //print("handler for shal_l\n", .{});
    //insn.display();
}
fn handle_shar_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = (a >> 1) | (a & 0x80);

    self.shl(oands, a);
    flg_shro(u8, self, a, b, (a&1)!=0);
    // V=0

    //print("handler for shar_b\n", .{});
    //insn.display();
}
fn handle_shar_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = (a >> 1) | (a & 0x8000);

    self.srn(oands, b);
    flg_shro(u16, self, a, b, (a&1)!=0);
    // V=0

    //print("handler for shar_w\n", .{});
    //insn.display();
}
fn handle_shar_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = (a >> 1) | (a & 0x80000000);

    self.ser(oands, b);
    flg_shro(u32, self, a, b, (a&1)!=0);
    // V=0

    //print("handler for shar_l\n", .{});
    //insn.display();
}
fn handle_shll_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = a << 1;

    self.shl(oands, @truncate(u8, b));
    flg_shro(u8, self, a, b, (a & 0x80)!=0);

    //print("handler for shll_b\n", .{});
    //insn.display();
}
fn handle_shll_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = a << 1;

    self.srn(oands, @truncate(u16, b));
    flg_shro(u16, self, a, b, (a & 0x8000)!=0);

    //print("handler for shll_w\n", .{});
    //insn.display();
}
fn handle_shll_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = a << 1;

    self.ser(oands, @truncate(u32, b));
    flg_shro(u32, self, a, b, (a & 0x80000000)!=0);

    //print("handler for shll_l\n", .{});
    //insn.display();
}
fn handle_shlr_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ghl(oands);
    const b = (a >> 1);

    self.shl(oands, a);
    flg_shro(u8, self, a, b, (a&1)!=0);
    // V=0

    //print("handler for shlr_b\n", .{});
    //insn.display();
}
fn handle_shlr_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.grn(oands);
    const b = (a >> 1);

    self.srn(oands, b);
    flg_shro(u16, self, a, b, (a&1)!=0);
    // V=0

    //print("handler for shlr_w\n", .{});
    //insn.display();
}
fn handle_shlr_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    const a = self.ger(oands);
    const b = (a >> 1);

    self.ser(oands, b);
    flg_shro(u32, self, a, b, (a&1)!=0);
    // V=0

    //print("handler for shlr_l\n", .{});
    //insn.display();
}
fn handle_sleep(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //print("handler for sleep\n", .{});
    //insn.display();
    @panic("not implemented!");
}
fn handle_stc_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    next(self);

    self.shl(oands, @enumToInt(self.ccr));

    //print("handler for stc_b\n", .{});
    //insn.display();
}
fn handle_stc_w_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = @enumToInt(self.ccr);
    const a = @truncate(u16, self.ger(oands));
    // TODO: WHAT DOES THIS ONE ACTUALLY DO?
    //self.write8(a ^ (a & 1), v); // this? // no, 16-bit bus access
    self.write16(a, @as(u16,v)); // this? or w/ v in the high byte too (cf. irqs)?
    // or does it *only* set the even byte? but it doesn't read, and it's a 16-bit access...

    //print("handler for stc_w_Mern\n", .{});
    //insn.display();
}
fn handle_stc_w_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = @enumToInt(self.ccr);
    const a = @truncate(u16, self.ger(oands.b)) +% oands.a;
    // TODO: WHAT DOES THIS ONE ACTUALLY DO?
    //self.write8(a ^ (a & 1), v); // this? // no, 16-bit bus access
    self.write16(a, @as(u16,v)); // this? or w/ v in the high byte too (cf. irqs)?
    // or does it *only* set the even byte? but it doesn't read, and it's a 16-bit access...

    //print("handler for stc_w_d16\n", .{});
    //insn.display();
}
fn handle_stc_w_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = @enumToInt(self.ccr);
    const a = @truncate(u16, self.ger(oands.b)) +% @truncate(u16, oands.a);
    // TODO: WHAT DOES THIS ONE ACTUALLY DO?
    //self.write8(a ^ (a & 1), v); // this? // no, 16-bit bus access
    self.write16(a, @as(u16,v)); // this? or w/ v in the high byte too (cf. irqs)?
    // or does it *only* set the even byte? but it doesn't read, and it's a 16-bit access...

    //print("handler for stc_w_d24\n", .{});
    //insn.display();
}
fn handle_stc_w_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = @enumToInt(self.ccr);
    const a = @truncate(u16, self.ger(oands) -% 2);
    self.ser(oands, self.ger(oands) -% 2);
    self.cycle(2);

    // TODO: WHAT DOES THIS ONE ACTUALLY DO?
    //self.write8(a ^ (a & 1), v); // this? // no, 16-bit bus access
    self.write16(a, @as(u16,v)); // this? or w/ v in the high byte too (cf. irqs)?
    // or does it *only* set the even byte? but it doesn't read, and it's a 16-bit access...

    //print("handler for stc_w_Mern_dec\n", .{});
    //insn.display();
}
fn handle_stc_w_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = @enumToInt(self.ccr);
    const a = oands;
    // TODO: WHAT DOES THIS ONE ACTUALLY DO?
    //self.write8(a ^ (a & 1), v); // this? // no, 16-bit bus access
    self.write16(a, @as(u16,v)); // this? or w/ v in the high byte too (cf. irqs)?
    // or does it *only* set the even byte? but it doesn't read, and it's a 16-bit access...

    //print("handler for stc_w_abs16\n", .{});
    //insn.display();
}
fn handle_stc_w_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    next(self);

    const v = @enumToInt(self.ccr);
    const a = @truncate(u16, oands);
    // TODO: WHAT DOES THIS ONE ACTUALLY DO?
    //self.write8(a ^ (a & 1), v); // this? // no, 16-bit bus access
    self.write16(a, @as(u16,v)); // this? or w/ v in the high byte too (cf. irqs)?
    // or does it *only* set the even byte? but it doesn't read, and it's a 16-bit access...

    //print("handler for stc_w_abs24\n", .{});
    //insn.display();
}
fn handle_sub_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = b -% a;
    self.srn(oands.b, r);
    flg_arith(u16, self, a, b, r, false, .sub);

    next(self);

    //print("handler for sub_w_imm\n", .{});
    //insn.display();
}
fn handle_sub_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = b -% a;
    self.ser(oands.b, r);
    flg_arith(u32, self, a, b, r, false, .sub);

    next(self);

    //print("handler for sub_l_imm\n", .{});
    //insn.display();
}
fn handle_sub_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = b -% a;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, false, .sub);

    next(self);

    //print("handler for sub_b_rn\n", .{});
    //insn.display();
}
fn handle_sub_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = b -% a;
    self.srn(oands.b, r);
    flg_arith(u16, self, a, b, r, false, .sub);

    next(self);

    //print("handler for sub_w_rn\n", .{});
    //insn.display();
}
fn handle_sub_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = b -% a;
    self.ser(oands.b, r);
    flg_arith(u32, self, a, b, r, false, .sub);

    next(self);

    //print("handler for sub_l_rn\n", .{});
    //insn.display();
}
fn handle_subs(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    self.ser(oands.b, self.ger(oands.b) -% oands.a.val());
    next(self);

    //print("handler for subs\n", .{});
    //insn.display();
}
fn handle_subx_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = b -% a;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, true, .sub);

    next(self);

    //print("handler for subx_imm\n", .{});
    //insn.display();
}
fn handle_subx_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = b -% a;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, true, .sub);

    next(self);

    //print("handler for subx_rn\n", .{});
    //insn.display();
}
fn handle_trapa(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    self.orp(@intToEnum(PendingExn, @enumToInt(PendingExn.trp0) << oands));
    // fallthrough to handle_exn, where the actual instruction handling stuff is done

    next(self);

    //print("handler for trapa\n", .{});
    //insn.display();
}
fn handle_xor_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a ^ b;
    self.shl(oands.b, r);
    flg_logic(u8, self, r);

    next(self);

    //print("handler for xor_b_imm\n", .{});
    //insn.display();
}
fn handle_xor_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = a ^ b;
    self.srn(oands.b, r);
    flg_logic(u16, self, r);

    next(self);

    //print("handler for xor_w_imm\n", .{});
    //insn.display();
}
fn handle_xor_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = a ^ b;
    self.ser(oands.b, r);
    flg_logic(u32, self, r);

    next(self);

    //print("handler for xor_l_imm\n", .{});
    //insn.display();
}
fn handle_xor_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a ^ b;
    self.shl(oands.b, r);
    flg_logic(u8, self, r);

    next(self);

    //print("handler for xor_b_rn\n", .{});
    //insn.display();
}
fn handle_xor_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = a ^ b;
    self.srn(oands.b, r);
    flg_logic(u16, self, r);

    next(self);

    //print("handler for xor_w_rn\n", .{});
    //insn.display();
}
fn handle_xor_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = a ^ b;
    self.ser(oands.b, r);
    flg_logic(u32, self, r);

    next(self);

    //print("handler for xor_l_rn\n", .{});
    //insn.display();
}
fn handle_xorc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    self.xorc(@intToEnum(CCR, oands));

    next(self);

    //print("handler for xorc\n", .{});
    //insn.display();
}

