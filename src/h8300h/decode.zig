
const std = @import("std");
const print = std.debug.print;
const expect = @import("std").testing.expect;

usingnamespace @import("insn.zig");

// TODO:
// * speed up opcode search
//   * currently a bad linear search aaaa
//   * long insns have common prefixes, maybe a better idea to recurse down
//     instead of using multiple tables (needs to happen statefully because
//     eg. add.l imm, rn's mask is only 0xfff800000000)
// * continuation fn // not really possible :/ (mk/Row needs rettype as arg...)

pub const MaskMatch = struct { ask: u16, atch: u16 };
pub fn Row(comptime n: comptime_int) type {
    return struct {
        mm: [n]MaskMatch,
        tag: Opcode,
        parse: fn (*Insn, []const u16) *Insn
    };
}

fn mk(comptime n: comptime_int, comptime mask: comptime_int,
        comptime match: comptime_int, comptime tag: Opcode, comptime fields: anytype) Row(n) {
    // insn is max 10 bytes in size
    if (mask < 0 or match < 0 or ((mask | match) & 0xffffffffffffffffffffff) != mask) {
        @compileError("mask too large -- max insn size is 10 bytes.");
    }
    if ((mask & match) != match or (mask | match) != mask) {
        @compileError("malformed match!");
    }
    if (n < 0 or n > 5) {
        @compileError("wtf?");
    }

    const pfn = struct {
        fn parseme(ret: *Insn, w: []const u16) *Insn {
            //var ret = @unionInit(Insn, @tagName(oc), undefined);

            comptime var allmask = ((1 << (n*16)) - 1);

            inline for (fields) |fmask, j| {
                allmask &= fmask;

                if ((mask & fmask) != 0) {
                    @compileLog("tag= ", tag, "mask=", fmask, "find=", j, "res=", (mask&fmask));
                    @compileError("insn mask and operand mask can't share bits");
                }

                comptime const shamt = @ctz(u128, fmask); // fields[j+0]
                comptime const msksz = 128-@clz(u128, fmask)-shamt;//@popCount(u128, fmask); // fields[j+1]
                comptime const fmaskv = fmask >> shamt; // (1 << msksz) - 1
                if (fmaskv != (1 << msksz) - 1
                        and tag != .adds and tag != .subs) {
                    @compileLog("badtag=", tag, "mask=", fmask, "find=", j, "res=", fmaskv, "res2=", ((1<<msksz)-1));
                    @compileError("operand mask: need one continuous range of set bits, not multiple sets of set bits");
                }

                comptime const intT =
                    if (msksz <= 16) u16
                    else if (msksz > 32) @compileError("operand mask size too large, 32 bits max, sorry") // TODO
                    else u32;
                const intv: intT =
                    if (msksz <= 16)
                        (w[n - (shamt >> 4) - 1] // shuffle stuff around for lexicographic nybble order
                            >> (shamt & 15)) & fmaskv // extract the wanted bits
                    else if (msksz > 32) @compileError("operand mask size too large, 32 bits max, sorry") // TODO
                    else
                        ((@intCast(intT,w[n - (shamt >> 4) - 1]) | (@intCast(intT,w[n - (shamt >> 4) - 2]) << 16))
                            >> (shamt & 15)) & fmaskv;
                const fldtyp = @TypeOf(@field(ret, @tagName(tag)));
                //print("intv=0x{x:} shamt={} msksz={} fmaskv=0x{x:}\n", .{intv,shamt,msksz,fmaskv});
                //if (intT == u32) {
                //    print("w-1 = {x:} ; w-2 = {x:}\n",
                //        .{@intCast(intT,w[n - (shamt >> 4) - 1]),
                //          (@intCast(intT,w[n - (shamt >> 4) - 2]) << 16)});
                //}
                //for (w) |wi,iii| print("w[{}] = {x:}\n", .{iii,wi});

                switch (@typeInfo(fldtyp)) {
                    .Void => {},
                    .Struct => {
                        const fldname = comptime switch (tag) {
                            .bcc_pcrel8, .bcc_pcrel16 => ([_][]const u8{"cc","a"})[j],
                            .mov_b_d16_rn, .mov_w_d16_rn, .mov_l_d16_rn,
                                .mov_b_d24_rn, .mov_w_d24_rn, .mov_l_d24_rn =>
                                    ([_][]const u8{"a1","a2","b"})[j],
                            .mov_b_rn_d16, .mov_w_rn_d16, .mov_l_rn_d16,
                                .mov_b_rn_d24, .mov_w_rn_d24, .mov_l_rn_d24 =>
                                    ([_][]const u8{"a","b1","b2"})[j],
                            else => ([_][]const u8{"a","b"})[j]
                        };

                        const typ = @TypeOf(@field(@field(ret, @tagName(tag)), fldname));

                        //if (@bitSizeOf(typ) != masksz) {
                        //    @compileError("bad mask size for field");
                        //}

                        @field(@field(ret, @tagName(tag)), fldname) =
                            if (@typeInfo(typ) == .Enum) @intToEnum(typ, @truncate(@TagType(typ), intv))
                            else @truncate(typ, intv)
                        ;
                    },
                    .Enum => {
                        @field(ret, @tagName(tag)) = @intToEnum(fldtyp, @truncate(@TagType(fldtyp), intv));
                    },
                    else => {
                        @field(ret, @tagName(tag)) = @truncate(fldtyp, intv);
                    }
                }

                if ((allmask & mask) != 0) {
                    @compileLog("masktag=", tag);
                    @compileError("bad operand masks for instruction: shared bits!");
                }
            }

            return ret;
        }
    }.parseme;

    var rv: Row(n) = .{ .parse = pfn, .mm = [_]MaskMatch{undefined} ** n, .tag = tag };

    var i: comptime_int = 0;
    inline while (i < n) : (i += 1) {
        // reverse word order => useful reading order
        const shift = (n - i - 1) * 16;
        rv.mm[i].ask = (mask  >> shift) & 0xffff;
        rv.mm[i].atch= (match >> shift) & 0xffff;
    }

    return rv;
}

const table1 = comptime [_]Row(1){
    mk(1, 0xf000, 0x8000, .add_b_imm , .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff00, 0x0800, .add_b_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x0900, .add_w_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff88, 0x0a80, .add_l_rn  , .{ 0x0070, 0x0007 }),
    mk(1, 0xff68, 0x0b00, .adds      , .{ 0x0090, 0x0007 }),
    mk(1, 0xf000, 0x9000, .addx_imm  , .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff00, 0x0e00, .addx_rn   , .{ 0x00f0, 0x000f }),
    mk(1, 0xf000, 0xe000, .and_b_imm , .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff00, 0x1600, .and_b_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x6600, .and_w_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x0600, .andc      , .{ 0x00ff         }),
    mk(1, 0xf000, 0x4000, .bcc_pcrel8, .{ 0x0f00, 0x00ff }),
    mk(1, 0xff00, 0x5500, .bsr_pcrel8, .{ 0x00ff         }),

    mk(1, 0xff80, 0x7600, .band_rn   , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7200, .bclr_imm_rn,.{ 0x0070, 0x000f }),
    mk(1, 0xff00, 0x6200, .bclr_rn_rn ,.{ 0x00f0, 0x000f }),
    mk(1, 0xff80, 0x7680, .biand_rn  , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7780, .bild_rn   , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7480, .bior_rn   , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x6780, .bist_rn   , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7580, .bixor_rn  , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7700, .bld_rn    , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7100, .bnot_imm_rn,.{ 0x0070, 0x000f }),
    mk(1, 0xff00, 0x6100, .bnot_rn_rn ,.{ 0x00f0, 0x000f }),
    mk(1, 0xff80, 0x7400, .bor_rn    , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7000, .bset_imm_rn,.{ 0x0070, 0x000f }),
    mk(1, 0xff00, 0x6000, .bset_rn_rn ,.{ 0x00f0, 0x000f }),
    mk(1, 0xff80, 0x6700, .bst_rn    , .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x7300, .btst_imm_rn,.{ 0x0070, 0x000f }),
    mk(1, 0xff00, 0x6300, .btst_rn_rn ,.{ 0x00f0, 0x000f }),
    mk(1, 0xff80, 0x7500, .bxor_rn   , .{ 0x0070, 0x000f }),

    mk(1, 0xf000, 0xa000, .cmp_b_imm , .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff00, 0x1c00, .cmp_b_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x1d00, .cmp_w_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff88, 0x1f80, .cmp_l_rn  , .{ 0x0070, 0x0007 }),
    mk(1, 0xfff0, 0x0f00, .daa       , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1f00, .das       , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1a00, .dec_b     , .{ 0x000f         }),
    mk(1, 0xff70, 0x1b50, .dec_w     , .{ 0x0080, 0x000f }),
    mk(1, 0xff78, 0x1b70, .dec_l     , .{ 0x0080, 0x0007 }),
    mk(1, 0xff00, 0x5100, .divxu_b   , .{ 0x00f0, 0x000f }),
    mk(1, 0xff08, 0x5300, .divxu_w   , .{ 0x00f0, 0x0007 }),
    mk(1, 0xfff0, 0x17d0, .exts_w    , .{ 0x000f         }),
    mk(1, 0xfff8, 0x17f0, .exts_l    , .{ 0x0007         }),
    mk(1, 0xfff0, 0x1750, .extu_w    , .{ 0x000f         }),
    mk(1, 0xfff8, 0x1770, .extu_l    , .{ 0x0007         }),
    mk(1, 0xfff0, 0x0a00, .inc_b     , .{ 0x000f         }),
    mk(1, 0xff70, 0x0b50, .inc_w     , .{ 0x0080, 0x000f }),
    mk(1, 0xff70, 0x0b70, .inc_l     , .{ 0x0080, 0x000f }),
    mk(1, 0xff8f, 0x5900, .jmp_Mern  , .{ 0x0070         }),
    mk(1, 0xff00, 0x5b00, .jmp_MMabs8, .{ 0x00ff         }),
    mk(1, 0xff8f, 0x5d00, .jsr_Mern  , .{ 0x0070         }),
    mk(1, 0xff00, 0x5f00, .jsr_MMabs8, .{ 0x00ff         }),
    mk(1, 0xff00, 0x0700, .ldc_b_imm , .{ 0x00ff         }),
    mk(1, 0xfff0, 0x0300, .ldc_b_rn  , .{ 0x000f         }),

    mk(1, 0xff00, 0x0c00, .mov_b_rn_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x0d00, .mov_w_rn_rn  , .{ 0x00f0, 0x000f }),
    mk(1, 0xff88, 0x0f80, .mov_l_rn_rn  , .{ 0x0070, 0x0007 }),
    mk(1, 0xf000, 0xf000, .mov_b_imm_rn , .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff80, 0x6800, .mov_b_Mern_rn, .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x6c00, .mov_b_Mern_inc_rn, .{ 0x0070, 0x000f }),
    mk(1, 0xf000, 0x2000, .mov_b_abs8_rn, .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff80, 0x6900, .mov_w_Mern_rn, .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x6d00, .mov_w_Mern_inc_rn, .{ 0x0070, 0x000f }),
    mk(1, 0xff80, 0x6880, .mov_b_rn_Mern, .{ 0x000f, 0x0070 }),
    mk(1, 0xff80, 0x6c80, .mov_b_rn_Mern_dec, .{ 0x000f, 0x0070 }),
    mk(1, 0xf000, 0x3000, .mov_b_rn_abs8, .{ 0x0f00, 0x00ff }),
    mk(1, 0xff80, 0x6980, .mov_w_rn_Mern, .{ 0x000f, 0x0070 }),
    mk(1, 0xff80, 0x6d80, .mov_w_rn_Mern_dec, .{ 0x000f, 0x0070 }),

    mk(1, 0xff00, 0x5000, .mulxu_b , .{ 0x00f0, 0x000f }),
    mk(1, 0xff08, 0x5200, .mulxu_w , .{ 0x00f0, 0x0007 }),
    mk(1, 0xfff0, 0x1780, .neg_b   , .{ 0x000f         }),
    mk(1, 0xfff0 ,0x1790, .neg_w   , .{ 0x000f         }),
    mk(1, 0xfff8, 0x17b0, .neg_l   , .{ 0x0007         }),
    mk(1, 0xffff, 0x0000, .nop     , .{                }),
    mk(1, 0xfff0, 0x1700, .not_b   , .{ 0x000f         }),
    mk(1, 0xfff0 ,0x1710, .not_w   , .{ 0x000f         }),
    mk(1, 0xfff8, 0x1730, .not_l   , .{ 0x0007         }),
    mk(1, 0xf000, 0xc000, .or_b_imm, .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff00, 0x1400, .or_b_rn , .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x6400, .or_w_rn , .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x0400, .orc     , .{ 0x00ff         }),
  //mk(1, 0xfff0, 0x6d70, .pop_w   , .{ 0x000f         }), // synonym for mov.w @er7+, Rn
  //mk(1, 0xfff0, 0x6df0, .push_w  , .{ 0x000f         }), // synonym for mov.w Rn, @-er7
    mk(1, 0xfff0, 0x1280, .rotl_b  , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1290, .rotl_w  , .{ 0x000f         }),
    mk(1, 0xfff8, 0x12b0, .rotl_l  , .{ 0x0007         }),
    mk(1, 0xfff0, 0x1380, .rotr_b  , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1390, .rotr_w  , .{ 0x000f         }),
    mk(1, 0xfff8, 0x13b0, .rotr_l  , .{ 0x0007         }),
    mk(1, 0xfff0, 0x1200, .rotxl_b , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1210, .rotxl_w , .{ 0x000f         }),
    mk(1, 0xfff8, 0x1230, .rotxl_l , .{ 0x0007         }),
    mk(1, 0xfff0, 0x1300, .rotxr_b , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1310, .rotxr_w , .{ 0x000f         }),
    mk(1, 0xfff8, 0x1330, .rotxr_l , .{ 0x0007         }),
    mk(1, 0xffff, 0x5670, .rte     , .{                }),
    mk(1, 0xffff, 0x5470, .rts     , .{                }),
    mk(1, 0xfff0, 0x1080, .shal_b  , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1090, .shal_w  , .{ 0x000f         }),
    mk(1, 0xfff8, 0x10b0, .shal_l  , .{ 0x0007         }),
    mk(1, 0xfff0, 0x1180, .shar_b  , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1190, .shar_w  , .{ 0x000f         }),
    mk(1, 0xfff8, 0x11b0, .shar_l  , .{ 0x0007         }),
    mk(1, 0xfff0, 0x1000, .shll_b  , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1010, .shll_w  , .{ 0x000f         }),
    mk(1, 0xfff8, 0x1030, .shll_l  , .{ 0x0007         }),
    mk(1, 0xfff0, 0x1100, .shlr_b  , .{ 0x000f         }),
    mk(1, 0xfff0, 0x1110, .shlr_w  , .{ 0x000f         }),
    mk(1, 0xfff8, 0x1130, .shlr_l  , .{ 0x0007         }),
    mk(1, 0xffff, 0x0180, .sleep   , .{                }),
    mk(1, 0xfff0, 0x0200, .stc_b   , .{ 0x000f         }),
    mk(1, 0xff00, 0x1800, .sub_b_rn, .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x1900, .sub_w_rn, .{ 0x00f0, 0x000f }),
    mk(1, 0xff88, 0x1a80, .sub_l_rn, .{ 0x0070, 0x0007 }),
    mk(1, 0xff68, 0x1b00, .subs    , .{ 0x0090, 0x0007 }),
    mk(1, 0xf000, 0xb000, .subx_imm, .{ 0x00ff, 0x0f00 }),
    mk(1, 0xff00, 0x1e00, .subx_rn , .{ 0x00f0, 0x000f }),
    mk(1, 0xffcf, 0x5700, .trapa   , .{ 0x0030         }),
    mk(1, 0xf000, 0xd000, .xor_b_imm,.{ 0x00ff, 0x0f00 }),
    mk(1, 0xff00, 0x1500, .xor_b_rn, .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x6500, .xor_w_rn, .{ 0x00f0, 0x000f }),
    mk(1, 0xff00, 0x0500, .xorc    , .{ 0x00ff         }),
};
const table2 = comptime [_]Row(2){
    mk(2, 0xfff00000, 0x79100000, .add_w_imm   , .{ 0x0000ffff, 0x000f0000 }),
    mk(2, 0xfff00000, 0x79600000, .and_w_imm   , .{ 0x0000ffff, 0x000f0000 }),
    mk(2, 0xffffff88, 0x01f06600, .and_l_rn    , .{ 0x00000070, 0x00000007 }),
    mk(2, 0xff0f0000, 0x58000000, .bcc_pcrel16 , .{ 0x00f00000, 0x0000ffff }),
    mk(2, 0xffff0000, 0x5c000000, .bsr_pcrel16 , .{ 0x0000ffff             }),

    mk(2, 0xff8fff8f, 0x7c007600, .band_Mern   , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007600, .band_abs8   , .{ 0x00000070, 0x00f00000 }),
    mk(2, 0xff8fff8f, 0x7d007200, .bclr_imm_Mern,.{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7f007200, .bclr_imm_abs8,.{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff0f, 0x7d006200, .bclr_rn_Mern, .{ 0x000000f0, 0x00700000 }),
    mk(2, 0xff00ff0f, 0x7f006200, .bclr_rn_abs8, .{ 0x000000f0, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007680, .biand_Mern  , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007680, .biand_abs8  , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007780, .bild_Mern   , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007780, .bild_abs8   , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007480, .bior_Mern   , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007480, .bior_abs8   , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7d006780, .bist_Mern   , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7f006780, .bist_abs8   , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007580, .bixor_Mern  , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007580, .bixor_abs8  , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007700, .bld_Mern    , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007700, .bld_abs8    , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7d007100, .bnot_imm_Mern,.{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7f007100, .bnot_imm_abs8,.{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff0f, 0x7d006100, .bnot_rn_Mern, .{ 0x000000f0, 0x00700000 }),
    mk(2, 0xff00ff0f, 0x7f006100, .bnot_rn_abs8, .{ 0x000000f0, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007400, .bor_Mern    , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007400, .bor_abs8    , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7d007000, .bset_imm_Mern,.{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7f007000, .bset_imm_abs8,.{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff0f, 0x7d006000, .bset_rn_Mern, .{ 0x000000f0, 0x00700000 }),
    mk(2, 0xff00ff0f, 0x7f006000, .bset_rn_abs8, .{ 0x000000f0, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7d006700, .bst_Mern    , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7f006700, .bst_abs8    , .{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007300, .btst_imm_Mern,.{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007300, .btst_imm_abs8,.{ 0x00000070, 0x00ff0000 }),
    mk(2, 0xff8fff0f, 0x7c006300, .btst_rn_Mern, .{ 0x000000f0, 0x00700000 }),
    mk(2, 0xff00ff0f, 0x7e006300, .btst_rn_abs8, .{ 0x000000f0, 0x00ff0000 }),
    mk(2, 0xff8fff8f, 0x7c007500, .bxor_Mern   , .{ 0x00000070, 0x00700000 }),
    mk(2, 0xff00ff8f, 0x7e007500, .bxor_abs8   , .{ 0x00000070, 0x00ff0000 }),

    mk(2, 0xfff00000, 0x79200000, .cmp_w_imm   , .{ 0x0000ffff, 0x000f0000 }),
    mk(2, 0xffffff00, 0x01d05100, .divxs_b     , .{ 0x000000f0, 0x0000000f }),
    mk(2, 0xffffff08, 0x01d05300, .divxs_w     , .{ 0x000000f0, 0x00000007 }),
    mk(2, 0xffffffff, 0x7b5c598f, .eepmov_b    , .{                        }),
    mk(2, 0xffffffff, 0x7bd4598f, .eepmov_w    , .{                        }),
    mk(2, 0xff000000, 0x5a000000, .jmp_abs24   , .{ 0x00ffffff             }),
    mk(2, 0xff000000, 0x5e000000, .jsr_abs24   , .{ 0x00ffffff             }),
    mk(2, 0xffffff8f, 0x01406900, .ldc_w_Mern  , .{ 0x00000070             }),
    mk(2, 0xffffff8f, 0x01406d00, .ldc_w_Mern_inc,.{0x00000070             }),

    mk(2, 0xff800000, 0x6e000000, .mov_b_d16_rn  , .{ 0x0000ffff, 0x00700000, 0x000f0000 }),
    mk(2, 0xfff00000, 0x6a000000, .mov_b_abs16_rn, .{ 0x0000ffff, 0x000f0000             }),
    mk(2, 0xfff00000, 0x79000000, .mov_w_imm_rn  , .{ 0x0000ffff, 0x000f0000             }),
    mk(2, 0xff800000, 0x6f000000, .mov_w_d16_rn  , .{ 0x0000ffff, 0x00700000, 0x000f0000 }),
    mk(2, 0xfff00000, 0x6b000000, .mov_w_abs16_rn, .{ 0x0000ffff, 0x000f0000             }),
    mk(2, 0xffffff88, 0x01006900, .mov_l_Mern_rn , .{ 0x00000070, 0x00000007             }),
    mk(2, 0xffffff88, 0x01006d00, .mov_l_Mern_inc_rn, .{ 0x00000070, 0x00000007          }),
    mk(2, 0xff800000, 0x6e800000, .mov_b_rn_d16  , .{ 0x000f0000, 0x0000ffff, 0x00700000 }),
    mk(2, 0xfff00000, 0x6a800000, .mov_b_rn_abs16, .{ 0x000f0000, 0x0000ffff             }),
    mk(2, 0xff800000, 0x6f800000, .mov_w_rn_d16  , .{ 0x000f0000, 0x0000ffff, 0x00700000 }),
    mk(2, 0xfff00000, 0x6b800000, .mov_w_rn_abs16, .{ 0x000f0000, 0x0000ffff             }),
    mk(2, 0xffffff88, 0x01006980, .mov_l_rn_Mern , .{ 0x00000007, 0x00000070             }),
    mk(2, 0xffffff88, 0x01006d80, .mov_l_rn_Mern_dec, .{ 0x00000007, 0x00000070          }),

    mk(2, 0xfff00000, 0x6a400000, .movfpe   , .{ 0x0000ffff, 0x000f0000 }),
    mk(2, 0xfff00000, 0x6ac00000, .movtpe   , .{ 0x000f0000, 0x0000ffff }),
    mk(2, 0xffffff00, 0x01c05000, .mulxs_b  , .{ 0x000000f0, 0x0000000f }),
    mk(2, 0xffffff08, 0x01c05200, .mulxs_w  , .{ 0x000000f0, 0x00000007 }),
    mk(2, 0xfff00000, 0x79400000, .or_w_imm , .{ 0x0000ffff, 0x000f0000 }),
    mk(2, 0xffffff88, 0x01f06400, .or_l_rn  , .{ 0x00000070, 0x00000007 }),
  //mk(2, 0xfffffff8, 0x01006d70, .pop_l    , .{ 0x00000007             }), // synonym for mov.l @er7+, ERn
  //mk(2, 0xfffffff8, 0x01006df0, .push_l   , .{ 0x00000007             }), // synonym for mov.l ERn, @-er7
    mk(2, 0xffffff8f, 0x01406980, .stc_w_Mern,.{ 0x00000070             }),
    mk(2, 0xffffff8f, 0x01406d80, .stc_w_Mern_dec , .{ 0x00000070       }),
    mk(2, 0xfff00000, 0x79300000, .sub_w_imm, .{ 0x0000ffff, 0x000f0000 }),
    mk(2, 0xfff00000, 0x79500000, .xor_w_imm, .{ 0x0000ffff, 0x000f0000 }),
    mk(2, 0xffffff88, 0x01f06500, .xor_l_rn , .{ 0x00000070, 0x00000007 }),
};
const table3 = comptime [_]Row(3){
    mk(3, 0xfff800000000, 0x7a1000000000, .add_l_imm, .{ 0x0000ffffffff, 0x000700000000 }),
    mk(3, 0xfff800000000, 0x7a6000000000, .and_l_imm, .{ 0x0000ffffffff, 0x000700000000 }),
    mk(3, 0xfff800000000, 0x7a2000000000, .cmp_l_imm, .{ 0x0000ffffffff, 0x000700000000 }),
    mk(3, 0xffffff8f0000, 0x01406f000000, .ldc_w_d16, .{ 0x00000000ffff, 0x000000700000 }),
    mk(3, 0xffffffff0000, 0x01406b000000, .ldc_w_abs16,.{0x00000000ffff                 }),

    mk(3, 0xfff0ff000000, 0x6a2000000000, .mov_b_abs24_rn, .{ 0x000000ffffff, 0x000f00000000 }),
    mk(3, 0xfff0ff000000, 0x6b2000000000, .mov_w_abs24_rn, .{ 0x000000ffffff, 0x000f00000000 }),
    mk(3, 0xfff800000000, 0x7a0000000000, .mov_l_imm_rn  , .{ 0x0000ffffffff, 0x000700000000 }),
    mk(3, 0xffffff880000, 0x01006f000000, .mov_l_d16_rn  , .{ 0x00000000ffff, 0x000000700000, 0x000000070000 }),
    mk(3, 0xfffffff80000, 0x01006b000000, .mov_l_abs16_rn, .{ 0x00000000ffff, 0x000000070000 }),
    mk(3, 0xfff0ff000000, 0x6aa000000000, .mov_b_rn_abs24, .{ 0x000f00000000, 0x000000ffffff }),
    mk(3, 0xfff0ff000000, 0x6ba000000000, .mov_w_rn_abs24, .{ 0x000f00000000, 0x000000ffffff }),
    mk(3, 0xffffff880000, 0x01006f800000, .mov_l_rn_d16  , .{ 0x000000070000, 0x00000000ffff, 0x000000700000 }),
    mk(3, 0xfffffff80000, 0x01006b800000, .mov_l_rn_abs16, .{ 0x000000070000, 0x00000000ffff }),

    mk(3, 0xfff800000000, 0x7a4000000000, .or_l_imm  , .{ 0x0000ffffffff, 0x000700000000 }),
    mk(3, 0xffffff8f0000, 0x01406f800000, .stc_w_d16 , .{ 0x00000000ffff, 0x000000700000 }),
    mk(3, 0xffffffff0000, 0x01406b800000, .stc_w_abs16,.{ 0x00000000ffff                 }),
    mk(3, 0xfff800000000, 0x7a3000000000, .sub_l_imm , .{ 0x0000ffffffff, 0x000700000000 }),
    mk(3, 0xfff800000000, 0x7a5000000000, .xor_l_imm , .{ 0x0000ffffffff, 0x000700000000 }),
};
const table4 = comptime [_]Row(4){
    mk(4, 0xffffffffff000000, 0x01406b2000000000, .ldc_w_abs24, .{ 0x0000000000ffffff }),

    mk(4, 0xff8ffff0ff000000, 0x78006a2000000000, .mov_b_d24_rn  , .{ 0x0000000000ffffff, 0x0070000000000000, 0x0000000f00000000 }),
    mk(4, 0xff8ffff0ff000000, 0x78006b2000000000, .mov_w_d24_rn  , .{ 0x0000000000ffffff, 0x0070000000000000, 0x0000000f00000000 }),
    mk(4, 0xfffffff8ff000000, 0x01006b2000000000, .mov_l_abs24_rn, .{ 0x0000000000ffffff, 0x0000000700000000 }),
    mk(4, 0xff8ffff0ff000000, 0x78006aa000000000, .mov_b_rn_d24  , .{ 0x0000000f00000000, 0x0000000000ffffff, 0x0070000000000000 }),
    mk(4, 0xff8ffff0ff000000, 0x78006ba000000000, .mov_w_rn_d24  , .{ 0x0000000f00000000, 0x0000000000ffffff, 0x0070000000000000 }),
    mk(4, 0xfffffff8ff000000, 0x01006ba000000000, .mov_l_rn_abs24, .{ 0x0000000700000000, 0x0000000000ffffff }),

    mk(4, 0xffffffffff000000, 0x01406ba000000000, .stc_w_abs24, .{ 0x0000000000ffffff }),
};
const table5 = comptime [_]Row(5){
    mk(5, 0xffffff8fffffff000000, 0x014078006b2000000000, .ldc_w_d24   , .{ 0x00000000000000ffffff, 0x00000070000000000000 }),

    mk(5, 0xffffff8ffff8ff000000, 0x010078006b2000000000, .mov_l_d24_rn, .{ 0x00000000000000ffffff, 0x00000070000000000000, 0x00000000000700000000 }),
    mk(5, 0xffffff8ffff8ff000000, 0x010078006ba000000000, .mov_l_rn_d24, .{ 0x00000000000700000000, 0x00000000000000ffffff, 0x00000070000000000000 }),

    mk(5, 0xffffff8fffffff000000, 0x014078006ba000000000, .stc_w_d24   , .{ 0x00000000000000ffffff, 0x00000070000000000000 }),
};

fn test_table(comptime M: comptime_int, comptime n: comptime_int,
              comptime tbl: [M]Row(n)) void {
    const bleh = ([_]u16{0})**n;

    for (tbl) |rowa, i| {
        for (tbl) |rowb, j| {
            if (i == j) continue;

            //print("test tbl{}: #{} <-> #{}\n", .{n, i, j});
            //const parseres = @as(Opcode, rowa.parse(rowa.tag, bleh[0..n]));
            if (rowa.tag == rowb.tag) {
                print("doubly used opcode {}\n", .{rowa.tag});
                expect(false);
            }

            // TODO: check conflicting tags (currently compiled into its 'parse' fn...)

            var cond2 = true;
            comptime var k = 0;
            inline while (k < n) : (k += 1) {
                const cond = (((rowa.mm[k].ask & rowb.mm[k].atch) == rowa.mm[k].atch
                        or (rowb.mm[k].ask & rowa.mm[k].atch) == rowb.mm[k].atch))
                        and rowa.mm[k].ask != 0 and rowb.mm[k].ask != 0;

                if (!cond) {
                    cond2 = false;
                    //break;
                }
            }

            if (cond2) {
                print("overlapping tbl{}: #{} <-> #{}, opcodes {} vs {}\n",
                    .{n, i, j, rowa.tag, rowb.tag});
            }
            expect(!cond2);
        }
    }
}

test "no_overlapping_isns" {
    test_table(table1.len, 1, table1);
    test_table(table2.len, 2, table2);
    test_table(table3.len, 3, table3);
    test_table(table4.len, 4, table4);
    test_table(table5.len, 5, table5);
}

inline fn decodeN(comptime M: comptime_int, comptime n: comptime_int,
        comptime tbl: [M]Row(n), iwds: []const u16) ?Insn {
    // TODO: better than just linear search
    inline for (tbl) |row| {
        var match = true;

        comptime var i = 0;
        inline while (i < n) : (i += 1) {
            if (match) {
                //print("mask={x:4} match={x:4} insnw={x:4} masked={x:4} tag={}\n",
                //    .{row.mm[i].ask, row.mm[i].atch, iwds[i],
                //        (row.mm[i].ask & iwds[i]), row.tag});

                if ((row.mm[i].ask & iwds[i]) != row.mm[i].atch) {
                    //print("no match\n", .{});
                    match = false;
                }
            }
        }

        if (match) {
            //print("match!\n", .{});
            var bleh = @unionInit(Insn, @tagName(row.tag), undefined);
            return row.parse(&bleh, iwds).*;
        }
    }

    //print("no {}-word match for ", .{n});
    //for (iwds) |nn| print("{x:4}", .{nn});
    //print("\n", .{});
    return null;
}
pub fn decode(insn: []const u16) ?Insn {
    return decodeN(table1.len, 1, table1, insn)
        orelse decodeN(table2.len, 2, table2, insn)
        orelse decodeN(table3.len, 3, table3, insn)
        orelse decodeN(table4.len, 4, table4, insn)
        orelse decodeN(table5.len, 5, table5, insn)
        orelse null;//@panic("invalid insn!");
}
pub inline fn decodeA(comptime n: comptime_int, insn: [n]u16) ?Insn { return decode(insn[0..n]); }

test "decoder" {
    const aaa = decodeA(1, [_]u16{0x8042}) orelse unreachable;
    expect(switch (aaa) {
        .add_b_imm => |ops| ops.a == 0x42 and ops.b == .r0h,
        else => blk: { aaa.display(); break :blk false; },
    });

    expect(switch (decodeA(2, [_]u16{0x7918,0x1337}) orelse unreachable) {
        .add_w_imm => |ops| blk: {
            //print("a=0x{x:} b={}\n", .{ops.a,ops.b});
            break :blk ops.a == 0x1337 and ops.b == .e0;
        },
        else => false,
    });

    expect(switch (decodeA(1, [_]u16{0x0ad5}) orelse unreachable) {
        .add_l_rn => |ops| ops.a == .er5 and ops.b == .er5,
        else => false,
    });

    expect(switch (decodeA(3, [_]u16{0x7a15,0x1337,0x6969}) orelse unreachable) {
        .add_l_imm => |ops| blk: {
            //print("a=0x{x:} b={}\n", .{ops.a,ops.b});
            break :blk ops.a == 0x13376969 and ops.b == .er5;
        },
        else => false,
    });

    expect(switch (decodeA(2, [_]u16{0x7b5c,0x598f}) orelse unreachable) {
        .eepmov_b => true,
        else => false,
    });
}

test "make me some handlerfns please" {
    comptime const ninsn = switch (@typeInfo(Opcode)) {
        .Enum => |e| blk2: {
            if (!e.is_exhaustive) @compileError("wtf!");
            break :blk2 e.fields.len;
        },
        else => @compileError("wtf")
    };

    comptime var i = 0;
    inline while (i < ninsn) : (i += 1) {
        comptime const the_tag = @intToEnum(Opcode, i);

        //print("fn handle_{}(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {{\n",
        //    .{ @tagName(the_tag) });
        //print("    print(\"handler for {}\\n\", .{{}});\n", .{ @tagName(the_tag) });
        //print("    insn.display();\n", .{});
        //print("}}\n", .{});
    }

    expect(true);
}

