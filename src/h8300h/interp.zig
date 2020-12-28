
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
            //insn.display();
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
//                    insn.display();
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
        self.sys.read16(self.pc+0),
        self.sys.read16(self.pc+2),
        self.sys.read16(self.pc+4),
        self.sys.read16(self.pc+6)
    };
    const insn = decode.decodeA(5, possible_words) orelse @panic("illegal insn!");
    self.stat();
    //insn.display();

    //print("table index #{}, tag {}\n", .{@enumToInt(@as(Opcode, insn)), @as(Opcode, insn)});
    const hrow = insntab[@enumToInt(@as(Opcode, insn))];
    hrow.handler(self, insn, possible_words[0..insn.size()]);

    //self.pc = @truncate(u16, self.pc + insn.size() * 2);
    //self.cycle((insn.size()-1)*2);
    //self.fetch = self.read16(self.pc - 2);
}

fn finf(self: *H8300H, raw: []const u16) void {
    var i: usize = 1;
    while (i < raw.len) : (i += 1) {
        _ = self.read16(self.pc);
        self.pc += 2;
    }
}
inline fn next(self: *H8300H) void {
    self.fetch = self.read16(self.pc);
    self.pc += 2;
}

fn flg_arith(comptime T: type, self: *H8300H, a: T, b: T, v: T, comptime x: bool) void {
    const rm = (v >> (@bitSizeOf(T)-1)) != 0;
    const sm = (a >> (@bitSizeOf(T)-1)) != 0;
    const dm = (b >> (@bitSizeOf(T)-1)) != 0;

    const rm4 = ((v >> (@bitSizeOf(T)-1-4))&1) != 0;
    const sm4 = ((a >> (@bitSizeOf(T)-1-4))&1) != 0;
    const dm4 = ((b >> (@bitSizeOf(T)-1-4))&1) != 0;

    const zzz = self.hasc(.z);
    self.andc(@intToEnum(CCR, 0xd0)); // i, u, ui
    if ((sm and dm) or (dm and !rm) or (sm and !rm)) self.orc(.c);
    if ((sm and dm and !rm) or (!sm and !dm and rm)) self.orc(.v);
    if (x) {
        if ((v == 0) and !zzz) self.orc(.z);
    } else {
        if (v == 0) self.orc(.z);
    }
    if (rm) self.orc(.n);
    if ((sm4 and dm4) or (dm4 and !rm4) or (sm4 and !rm4)) self.orc(.h);
}
fn flg_logic(comptime T: type, self: *H8300H, a: T, b: T, v: T) void {
    self.andc(@intToEnum(CCR, 0xd0|36)); // i, u, ui, h, c
    if (v == 0) self.orc(.z);
    if ((v >> (@bitSizeOf(T)-1)) != 0) self.orc(.n);
}

fn handle_add_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, false);

    next(self);

    print("handler for add_b_imm\n", .{});
    insn.display();
}
fn handle_add_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = a +% b;
    self.srn(oands.b, r);
    flg_arith(u16, self, a, b, r, false);

    next(self);

    print("handler for add_w_imm\n", .{});
    insn.display();
}
fn handle_add_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = a +% b;
    self.ser(oands.b, r);
    flg_arith(u32, self, a, b, r, false);

    next(self);

    print("handler for add_l_imm\n", .{});
    insn.display();
}
fn handle_add_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, false);

    next(self);

    print("handler for add_b_rn\n", .{});
    insn.display();
}
fn handle_add_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = a +% b;
    self.srn(oands.b, r);
    flg_arith(u16, self, a, b, r, false);

    next(self);

    print("handler for add_w_rn\n", .{});
    insn.display();
}
fn handle_add_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = a +% b;
    self.ser(oands.b, r);
    flg_arith(u32, self, a, b, r, false);

    next(self);

    print("handler for add_l_rn\n", .{});
    insn.display();
}
fn handle_adds(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    self.ser(oands.b, self.ger(oands.b) +% oands.a.val());
    next(self);

    print("handler for adds\n", .{});
    insn.display();
}
fn handle_addx_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, true);

    next(self);

    print("handler for addx_imm\n", .{});
    insn.display();
}
fn handle_addx_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a +% b;
    self.shl(oands.b, r);
    flg_arith(u8, self, a, b, r, true);

    next(self);

    print("handler for addx_rn\n", .{});
    insn.display();
}
fn handle_and_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = oands.a;
    const b = self.ghl(oands.b);
    const r = a & b;
    self.shl(oands.b, r);
    flg_logic(u8, self, a, b, r);

    next(self);

    print("handler for and_b_imm\n", .{});
    insn.display();
}
fn handle_and_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.grn(oands.b);
    const r = a & b;
    self.srn(oands.b, r);
    flg_logic(u16, self, a, b, r);

    next(self);

    print("handler for and_w_imm\n", .{});
    insn.display();
}
fn handle_and_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = oands.a;
    const b = self.ger(oands.b);
    const r = a & b;
    self.ser(oands.b, r);
    flg_logic(u32, self, a, b, r);

    next(self);

    print("handler for and_l_imm\n", .{});
    insn.display();
}
fn handle_and_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const a = self.ghl(oands.a);
    const b = self.ghl(oands.b);
    const r = a & b;
    self.shl(oands.b, r);
    flg_logic(u8, self, a, b, r);

    next(self);

    print("handler for and_b_rn\n", .{});
    insn.display();
}
fn handle_and_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.grn(oands.a);
    const b = self.grn(oands.b);
    const r = a & b;
    self.srn(oands.b, r);
    flg_logic(u16, self, a, b, r);

    next(self);

    print("handler for and_w_rn\n", .{});
    insn.display();
}
fn handle_and_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = self.ger(oands.a);
    const b = self.ger(oands.b);
    const r = a & b;
    self.ser(oands.b, r);
    flg_logic(u32, self, a, b, r);

    next(self);

    print("handler for and_l_rn\n", .{});
    insn.display();
}
fn handle_andc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    self.andc(@intToEnum(CCR, oands));

    next(self);

    print("handler for andc\n", .{});
    insn.display();
}
fn handle_bcc_pcrel8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    next(self);

    const offu16 = if ((oands.a & 0x80) != 0) (0xff00 | @as(u16, oands.a))
                   else @as(u16, oands.a);
    const ea = self.pc +% offu16;
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

    print("handler for bcc_pcrel8\n", .{});
    insn.display();
}
fn handle_bcc_pcrel16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    self.cycle(2);

    const ea = self.pc +% oands.a;
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

    print("handler for bcc_pcrel16\n", .{});
    insn.display();
}
fn handle_bsr_pcrel8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);
    next(self);

    const oldpc = self.pc;
    const offu16 = if ((oands & 0x80) != 0) (0xff00 | @as(u16, oands))
                   else @as(u16, oands);
    const ea = oldpc +% offu16;
    self.pc = ea;
    next(self);

    self.write16(self.gsp(), oldpc);
    self.ssp(self.gsp() -% 2);

    print("handler for bsr_pcrel8\n", .{});
    insn.display();
}
fn handle_bsr_pcrel16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);
    self.cycle(2);

    const oldpc = self.pc;
    const ea = oldpc +% oands;
    self.pc = ea;
    next(self);

    self.write16(self.gsp(), oldpc);
    self.ssp(self.gsp() -% 2);

    print("handler for bsr_pcrel16\n", .{});
    insn.display();
}
fn handle_band_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r != 0) .c else .none);

    next(self);
    print("handler for band_rn\n", .{});
    insn.display();
}
fn handle_band_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r != 0) .c else .none);

    next(self);
    print("handler for band_Mern\n", .{});
    insn.display();
}
fn handle_band_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const m = self.read8(@as(u16, oands.b) | 0xff00);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r != 0) .c else .none);

    next(self);
    print("handler for band_abs8\n", .{});
    insn.display();
}
fn handle_bclr_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const r = m & ~(@as(u8,1) << oands.a);
    self.shl(oands.b, r);

    next(self);
    print("handler for bclr_imm_rn\n", .{});
    insn.display();
}
fn handle_bclr_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << oands.a);
    next(self);
    self.write8(a, r);

    print("handler for bclr_imm_Mern\n", .{});
    insn.display();
}
fn handle_bclr_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << oands.a);
    next(self);
    self.write8(a, r);

    print("handler for bclr_imm_abs8\n", .{});
    insn.display();
}
fn handle_bclr_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const m = self.ghl(oands.b);
    const r = m & ~(@as(u8,1) << (@truncate(u3,self.ghl(oands.a)) & 7));
    self.shl(oands.b, r);

    next(self);
    print("handler for bclr_rn_rn\n", .{});
    insn.display();
}
fn handle_bclr_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << (@truncate(u3,self.ghl(oands.a)) & 7));
    next(self);
    self.write8(a, r);

    print("handler for bclr_rn_Mern\n", .{});
    insn.display();
}
fn handle_bclr_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & ~(@as(u8,1) << (@truncate(u3,self.ghl(oands.a)) & 7));
    next(self);
    self.write8(a, r);

    print("handler for bclr_rn_abs8\n", .{});
    insn.display();
}
fn handle_biand_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r == 0) .c else .none);

    next(self);
    print("handler for biand_rn\n", .{});
    insn.display();
}
fn handle_biand_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r == 0) .c else .none);

    next(self);
    print("handler for biand_Mern\n", .{});
    insn.display();
}
fn handle_biand_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) and r == 0) .c else .none);

    next(self);
    print("handler for biand_abs8\n", .{});
    insn.display();
}
fn handle_bild_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (r == 0) .c else .none);

    next(self);
    print("handler for bild_rn\n", .{});
    insn.display();
}
fn handle_bild_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16,self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (r == 0) .c else .none);

    next(self);
    print("handler for bild_Mern\n", .{});
    insn.display();
}
fn handle_bild_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (r == 0) .c else .none);

    next(self);
    print("handler for bild_abs8\n", .{});
    insn.display();
}
fn handle_bior_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    //finf(self, raw);

    const r = self.ghl(oands.b) & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r == 0) .c else .none);

    next(self);
    print("handler for bior_rn\n", .{});
    insn.display();
}
fn handle_bior_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @truncate(u16, self.ger(oands.b));
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r == 0) .c else .none);

    next(self);
    print("handler for bior_Mern\n", .{});
    insn.display();
}
fn handle_bior_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    finf(self, raw);

    const a = @as(u16, oands.b) | 0xff00;
    const m = self.read8(a);
    const r = m & (@as(u8,1) << oands.a);
    self.setc(.c, if (self.hasc(.c) or r == 0) .c else .none);

    next(self);
    print("handler for bior_abs8\n", .{});
    insn.display();
}
fn handle_bist_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const m = self.ghl(oands.b);
    const v = (m & ~(@as(u8,1) << oands.a))
            | (@as(u8, @boolToInt(self.hasc(.c))) << oands.a);
    self.shl(oands.b, v);

    next(self);
    print("handler for bist_rn\n", .{});
    insn.display();
}
fn handle_bist_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bist_Mern\n", .{});
    insn.display();
}
fn handle_bist_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bist_abs8\n", .{});
    insn.display();
}
fn handle_bixor_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bixor_rn\n", .{});
    insn.display();
}
fn handle_bixor_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bixor_Mern\n", .{});
    insn.display();
}
fn handle_bixor_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bixor_abs8\n", .{});
    insn.display();
}
fn handle_bld_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bld_rn\n", .{});
    insn.display();
}
fn handle_bld_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bld_Mern\n", .{});
    insn.display();
}
fn handle_bld_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bld_abs8\n", .{});
    insn.display();
}
fn handle_bnot_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bnot_imm_rn\n", .{});
    insn.display();
}
fn handle_bnot_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bnot_imm_Mern\n", .{});
    insn.display();
}
fn handle_bnot_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bnot_imm_abs8\n", .{});
    insn.display();
}
fn handle_bnot_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bnot_rn_rn\n", .{});
    insn.display();
}
fn handle_bnot_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bnot_rn_Mern\n", .{});
    insn.display();
}
fn handle_bnot_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bnot_rn_abs8\n", .{});
    insn.display();
}
fn handle_bor_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bor_rn\n", .{});
    insn.display();
}
fn handle_bor_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bor_Mern\n", .{});
    insn.display();
}
fn handle_bor_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bor_abs8\n", .{});
    insn.display();
}
fn handle_bset_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bset_imm_rn\n", .{});
    insn.display();
}
fn handle_bset_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bset_imm_Mern\n", .{});
    insn.display();
}
fn handle_bset_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bset_imm_abs8\n", .{});
    insn.display();
}
fn handle_bset_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bset_rn_rn\n", .{});
    insn.display();
}
fn handle_bset_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bset_rn_Mern\n", .{});
    insn.display();
}
fn handle_bset_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bset_rn_abs8\n", .{});
    insn.display();
}
fn handle_bst_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bst_rn\n", .{});
    insn.display();
}
fn handle_bst_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bst_Mern\n", .{});
    insn.display();
}
fn handle_bst_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bst_abs8\n", .{});
    insn.display();
}
fn handle_btst_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for btst_imm_rn\n", .{});
    insn.display();
}
fn handle_btst_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for btst_imm_Mern\n", .{});
    insn.display();
}
fn handle_btst_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for btst_imm_abs8\n", .{});
    insn.display();
}
fn handle_btst_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for btst_rn_rn\n", .{});
    insn.display();
}
fn handle_btst_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for btst_rn_Mern\n", .{});
    insn.display();
}
fn handle_btst_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for btst_rn_abs8\n", .{});
    insn.display();
}
fn handle_bxor_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bxor_rn\n", .{});
    insn.display();
}
fn handle_bxor_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bxor_Mern\n", .{});
    insn.display();
}
fn handle_bxor_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bxor_abs8\n", .{});
    insn.display();
}
fn handle_cmp_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for cmp_b_imm\n", .{});
    insn.display();
}
fn handle_cmp_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for cmp_w_imm\n", .{});
    insn.display();
}
fn handle_cmp_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for cmp_l_imm\n", .{});
    insn.display();
}
fn handle_cmp_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for cmp_b_rn\n", .{});
    insn.display();
}
fn handle_cmp_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for cmp_w_rn\n", .{});
    insn.display();
}
fn handle_cmp_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for cmp_l_rn\n", .{});
    insn.display();
}
fn handle_daa(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for daa\n", .{});
    insn.display();
}
fn handle_das(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for das\n", .{});
    insn.display();
}
fn handle_dec_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for dec_b\n", .{});
    insn.display();
}
fn handle_dec_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for dec_w\n", .{});
    insn.display();
}
fn handle_dec_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for dec_l\n", .{});
    insn.display();
}
fn handle_divxs_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for divxs_b\n", .{});
    insn.display();
}
fn handle_divxs_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for divxs_w\n", .{});
    insn.display();
}
fn handle_divxu_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for divxu_b\n", .{});
    insn.display();
}
fn handle_divxu_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for divxu_w\n", .{});
    insn.display();
}
fn handle_eepmov_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for eepmov_b\n", .{});
    insn.display();
}
fn handle_eepmov_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for eepmov_w\n", .{});
    insn.display();
}
fn handle_exts_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for exts_w\n", .{});
    insn.display();
}
fn handle_exts_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for exts_l\n", .{});
    insn.display();
}
fn handle_extu_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for extu_w\n", .{});
    insn.display();
}
fn handle_extu_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for extu_l\n", .{});
    insn.display();
}
fn handle_inc_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for inc_b\n", .{});
    insn.display();
}
fn handle_inc_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for inc_w\n", .{});
    insn.display();
}
fn handle_inc_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for inc_l\n", .{});
    insn.display();
}
fn handle_jmp_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for jmp_Mern\n", .{});
    insn.display();
}
fn handle_jmp_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for jmp_abs24\n", .{});
    insn.display();
}
fn handle_jmp_MMabs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for jmp_MMabs8\n", .{});
    insn.display();
}
fn handle_jsr_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for jsr_Mern\n", .{});
    insn.display();
}
fn handle_jsr_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for jsr_abs24\n", .{});
    insn.display();
}
fn handle_jsr_MMabs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for jsr_MMabs8\n", .{});
    insn.display();
}
fn handle_ldc_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_b_imm\n", .{});
    insn.display();
}
fn handle_ldc_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_b_rn\n", .{});
    insn.display();
}
fn handle_ldc_w_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_w_Mern\n", .{});
    insn.display();
}
fn handle_ldc_w_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_w_d16\n", .{});
    insn.display();
}
fn handle_ldc_w_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_w_d24\n", .{});
    insn.display();
}
fn handle_ldc_w_Mern_inc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_w_Mern_inc\n", .{});
    insn.display();
}
fn handle_ldc_w_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_w_abs16\n", .{});
    insn.display();
}
fn handle_ldc_w_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for ldc_w_abs24\n", .{});
    insn.display();
}
fn handle_mov_b_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_rn\n", .{});
    insn.display();
}
fn handle_mov_w_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_rn_rn\n", .{});
    insn.display();
}
fn handle_mov_l_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_rn_rn\n", .{});
    insn.display();
}
fn handle_mov_b_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_imm_rn\n", .{});
    insn.display();
}
fn handle_mov_w_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    const a = oands.a;
    const b = &self.reg[@enumToInt(oands.b) & 7];
    if ((@enumToInt(oands.b) & 8) == 1) { // en
        b.* = (b.* & 0x0000ffff) | (@as(u32,a) << 16);
    } else {
        b.* = (b.* & 0xffff0000) | (@as(u32,a) << 00);
    }

    print("handler for mov_w_imm_rn\n", .{});
    insn.display();
}
fn handle_mov_l_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_imm_rn\n", .{});
    insn.display();
}
fn handle_mov_b_Mern_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_Mern_rn\n", .{});
    insn.display();
}
fn handle_mov_w_Mern_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_Mern_rn\n", .{});
    insn.display();
}
fn handle_mov_l_Mern_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_Mern_rn\n", .{});
    insn.display();
}
fn handle_mov_b_d16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_d16_rn\n", .{});
    insn.display();
}
fn handle_mov_w_d16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_d16_rn\n", .{});
    insn.display();
}
fn handle_mov_l_d16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_d16_rn\n", .{});
    insn.display();
}
fn handle_mov_b_d24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_d24_rn\n", .{});
    insn.display();
}
fn handle_mov_w_d24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_d24_rn\n", .{});
    insn.display();
}
fn handle_mov_l_d24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_d24_rn\n", .{});
    insn.display();
}
fn handle_mov_b_Mern_inc_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_Mern_inc_rn\n", .{});
    insn.display();
}
fn handle_mov_w_Mern_inc_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_Mern_inc_rn\n", .{});
    insn.display();
}
fn handle_mov_l_Mern_inc_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_Mern_inc_rn\n", .{});
    insn.display();
}
fn handle_mov_b_abs8_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_abs8_rn\n", .{});
    insn.display();
}
fn handle_mov_b_abs16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_abs16_rn\n", .{});
    insn.display();
}
fn handle_mov_w_abs16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_abs16_rn\n", .{});
    insn.display();
}
fn handle_mov_l_abs16_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_abs16_rn\n", .{});
    insn.display();
}
fn handle_mov_b_abs24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_abs24_rn\n", .{});
    insn.display();
}
fn handle_mov_w_abs24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_abs24_rn\n", .{});
    insn.display();
}
fn handle_mov_l_abs24_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_abs24_rn\n", .{});
    insn.display();
}
fn handle_mov_b_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_Mern\n", .{});
    insn.display();
}
fn handle_mov_w_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_rn_Mern\n", .{});
    insn.display();
}
fn handle_mov_l_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_rn_Mern\n", .{});
    insn.display();
}
fn handle_mov_b_rn_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_d16\n", .{});
    insn.display();
}
fn handle_mov_w_rn_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_rn_d16\n", .{});
    insn.display();
}
fn handle_mov_l_rn_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_rn_d16\n", .{});
    insn.display();
}
fn handle_mov_b_rn_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_d24\n", .{});
    insn.display();
}
fn handle_mov_w_rn_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_rn_d24\n", .{});
    insn.display();
}
fn handle_mov_l_rn_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_rn_d24\n", .{});
    insn.display();
}
fn handle_mov_b_rn_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_Mern_dec\n", .{});
    insn.display();
}
fn handle_mov_w_rn_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_rn_Mern_dec\n", .{});
    insn.display();
}
fn handle_mov_l_rn_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_rn_Mern_dec\n", .{});
    insn.display();
}
fn handle_mov_b_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_abs8\n", .{});
    insn.display();
}
fn handle_mov_b_rn_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_abs16\n", .{});
    insn.display();
}
fn handle_mov_w_rn_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_rn_abs16\n", .{});
    insn.display();
}
fn handle_mov_l_rn_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_rn_abs16\n", .{});
    insn.display();
}
fn handle_mov_b_rn_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_b_rn_abs24\n", .{});
    insn.display();
}
fn handle_mov_w_rn_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_w_rn_abs24\n", .{});
    insn.display();
}
fn handle_mov_l_rn_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mov_l_rn_abs24\n", .{});
    insn.display();
}
fn handle_movfpe(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for movfpe\n", .{});
    insn.display();
}
fn handle_movtpe(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for movtpe\n", .{});
    insn.display();
}
fn handle_mulxs_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mulxs_b\n", .{});
    insn.display();
}
fn handle_mulxs_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mulxs_w\n", .{});
    insn.display();
}
fn handle_mulxu_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mulxu_b\n", .{});
    insn.display();
}
fn handle_mulxu_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for mulxu_w\n", .{});
    insn.display();
}
fn handle_neg_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for neg_b\n", .{});
    insn.display();
}
fn handle_neg_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for neg_w\n", .{});
    insn.display();
}
fn handle_neg_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for neg_l\n", .{});
    insn.display();
}
fn handle_nop(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for nop\n", .{});
    insn.display();
}
fn handle_not_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for not_b\n", .{});
    insn.display();
}
fn handle_not_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for not_w\n", .{});
    insn.display();
}
fn handle_not_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for not_l\n", .{});
    insn.display();
}
fn handle_or_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for or_b_imm\n", .{});
    insn.display();
}
fn handle_or_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for or_w_imm\n", .{});
    insn.display();
}
fn handle_or_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for or_l_imm\n", .{});
    insn.display();
}
fn handle_or_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for or_b_rn\n", .{});
    insn.display();
}
fn handle_or_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for or_w_rn\n", .{});
    insn.display();
}
fn handle_or_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for or_l_rn\n", .{});
    insn.display();
}
fn handle_orc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for orc\n", .{});
    insn.display();
}
fn handle_rotl_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotl_b\n", .{});
    insn.display();
}
fn handle_rotl_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotl_w\n", .{});
    insn.display();
}
fn handle_rotl_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotl_l\n", .{});
    insn.display();
}
fn handle_rotr_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotr_b\n", .{});
    insn.display();
}
fn handle_rotr_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotr_w\n", .{});
    insn.display();
}
fn handle_rotr_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotr_l\n", .{});
    insn.display();
}
fn handle_rotxl_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotxl_b\n", .{});
    insn.display();
}
fn handle_rotxl_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotxl_w\n", .{});
    insn.display();
}
fn handle_rotxl_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotxl_l\n", .{});
    insn.display();
}
fn handle_rotxr_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotxr_b\n", .{});
    insn.display();
}
fn handle_rotxr_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotxr_w\n", .{});
    insn.display();
}
fn handle_rotxr_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rotxr_l\n", .{});
    insn.display();
}
fn handle_rte(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rte\n", .{});
    insn.display();
}
fn handle_rts(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for rts\n", .{});
    insn.display();
}
fn handle_shal_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shal_b\n", .{});
    insn.display();
}
fn handle_shal_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shal_w\n", .{});
    insn.display();
}
fn handle_shal_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shal_l\n", .{});
    insn.display();
}
fn handle_shar_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shar_b\n", .{});
    insn.display();
}
fn handle_shar_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shar_w\n", .{});
    insn.display();
}
fn handle_shar_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shar_l\n", .{});
    insn.display();
}
fn handle_shll_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shll_b\n", .{});
    insn.display();
}
fn handle_shll_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shll_w\n", .{});
    insn.display();
}
fn handle_shll_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shll_l\n", .{});
    insn.display();
}
fn handle_shlr_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shlr_b\n", .{});
    insn.display();
}
fn handle_shlr_w(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shlr_w\n", .{});
    insn.display();
}
fn handle_shlr_l(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for shlr_l\n", .{});
    insn.display();
}
fn handle_sleep(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for sleep\n", .{});
    insn.display();
}
fn handle_stc_b(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for stc_b\n", .{});
    insn.display();
}
fn handle_stc_w_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for stc_w_Mern\n", .{});
    insn.display();
}
fn handle_stc_w_d16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for stc_w_d16\n", .{});
    insn.display();
}
fn handle_stc_w_d24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for stc_w_d24\n", .{});
    insn.display();
}
fn handle_stc_w_Mern_dec(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for stc_w_Mern_dec\n", .{});
    insn.display();
}
fn handle_stc_w_abs16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for stc_w_abs16\n", .{});
    insn.display();
}
fn handle_stc_w_abs24(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for stc_w_abs24\n", .{});
    insn.display();
}
fn handle_sub_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for sub_w_imm\n", .{});
    insn.display();
}
fn handle_sub_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for sub_l_imm\n", .{});
    insn.display();
}
fn handle_sub_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for sub_b_rn\n", .{});
    insn.display();
}
fn handle_sub_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for sub_w_rn\n", .{});
    insn.display();
}
fn handle_sub_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for sub_l_rn\n", .{});
    insn.display();
}
fn handle_subs(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for subs\n", .{});
    insn.display();
}
fn handle_subx_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for subx_imm\n", .{});
    insn.display();
}
fn handle_subx_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for subx_rn\n", .{});
    insn.display();
}
fn handle_trapa(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for trapa\n", .{});
    insn.display();
}
fn handle_xor_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for xor_b_imm\n", .{});
    insn.display();
}
fn handle_xor_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for xor_w_imm\n", .{});
    insn.display();
}
fn handle_xor_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for xor_l_imm\n", .{});
    insn.display();
}
fn handle_xor_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for xor_b_rn\n", .{});
    insn.display();
}
fn handle_xor_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for xor_w_rn\n", .{});
    insn.display();
}
fn handle_xor_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for xor_l_rn\n", .{});
    insn.display();
}
fn handle_xorc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for xorc\n", .{});
    insn.display();
}

