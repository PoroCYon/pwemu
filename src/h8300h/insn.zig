
const std = @import("std");
const print = std.debug.print;

// Rn: register direct
// @Rn: register indirect
// @(d:(16|24), ERn): reg. indirect with offset/displacement
// @ERn+, @-ERn: post-inc/pre-dec ---> @Rn+: carries to En! (indirect!)
// @aa:(8|16|24): absolute add (8-bit: "zeropage:" at H'FFxx)
// #xx:(8|16|32): immediate
// @(d:(8|16),pc): pcrel
// @@aa:8: mem-indirect (8-bit: H'00xx) (used by jmp/jsr)
//
// ERn, En, Rn, RnH, RnL
// 'general register' "Rn" = RnL,RnH,Rn,En,ERn
// '(EAn)' == 'generic operand'

// rn: 4 bits: r0..r7, e0..e7 (.w) OR r0h..r7h, r0l..r7l (.b)
// ern: 3 bits: er0..er7 (.l)

pub const CCode = enum(u4) {
    a  = 0, n  = 1,
    hi = 2, ls = 3,
    cc = 4, cs = 5,
    ne = 6, eq = 7, vc = 8, vs = 9,
    pl =10, mi =11, ge =12, lt =13, gt =14, le =15,

    //t = 0, f = 1, hs = 4, lo = 5 // aliases // TODO AAAAA enums lack features ;-;
};
pub const OpRnHL = enum(u4) {
    r0h = 0, r1h = 1, r2h = 2, r3h = 3, r4h = 4, r5h = 5, r6h = 6, r7h = 7,
    r0l = 8, r1l = 9, r2l =10, r3l =11, r4l =12, r5l =13, r6l =14, r7l =15
};
pub const OpRn = enum(u4) {
    r0 = 0, r1 = 1, r2 = 2, r3 = 3, r4 = 4, r5 = 5, r6 = 6, r7 = 7,
    e0 = 8, e1 = 9, e2 =10, e3 =11, e4 =12, e5 =13, e6 =14, e7 =15
};
pub const OpERn = enum(u3) {
    er0 = 0, er1 = 1, er2 = 2, er3 = 3, er4 = 4, er5 = 5, er6 = 6, er7 = 7
};
pub const I12 = enum(u1) {
    one = 0, two = 1,

    pub inline fn val(self: I12) u2 {
        return switch (self) {
            .one => 1,
            .two => 2
        };
    }
};
pub const I124 = enum(u4) {
    one = 0, two = 8, four = 9,

    pub inline fn val(self: I124) u3 {
        return switch (self) {
            .one  => 1,
            .two  => 2,
            .four => 4,
        };
    }
};
pub const Opcode = enum {
    add_b_imm, add_w_imm, add_l_imm, add_b_rn, add_w_rn, add_l_rn, // imm, rn or rn, rn
    adds, // {1,2,4}, rn
    addx_imm, addx_rn, // imm, rn or rn, rn
    and_b_imm, and_w_imm, and_l_imm, and_b_rn, and_w_rn, and_l_rn, // imm, rn or rn, rn
    andc, // imm, ccr
    bcc_pcrel8, bcc_pcrel16, bsr_pcrel8, bsr_pcrel16,

    band_rn, band_Mern, band_abs8, // imm3, <operand>
    bclr_imm_rn, bclr_imm_Mern, bclr_imm_abs8, bclr_rn_rn, bclr_rn_Mern, bclr_rn_abs8,
    biand_rn, biand_Mern, biand_abs8, // imm3, <operand>
    bild_rn, bild_Mern, bild_abs8, // imm3, <operand>
    bior_rn, bior_Mern, bior_abs8, // imm3, <operand>
    bist_rn, bist_Mern, bist_abs8, // imm3, <operand>
    bixor_rn, bixor_Mern, bixor_abs8, // imm3, <operand>
    bld_rn, bld_Mern, bld_abs8, // imm3, <operand>
    bnot_imm_rn, bnot_imm_Mern, bnot_imm_abs8, bnot_rn_rn, bnot_rn_Mern, bnot_rn_abs8,
    bor_rn, bor_Mern, bor_abs8, // imm3, <operand>
    bset_imm_rn, bset_imm_Mern, bset_imm_abs8, bset_rn_rn, bset_rn_Mern, bset_rn_abs8,
    bst_rn, bst_Mern, bst_abs8, // imm3, <operand>
    btst_imm_rn, btst_imm_Mern, btst_imm_abs8, btst_rn_rn, btst_rn_Mern, btst_rn_abs8,
    bxor_rn, bxor_Mern, bxor_abs8, // imm3, <operand>

    cmp_b_imm, cmp_w_imm, cmp_l_imm, cmp_b_rn, cmp_w_rn, cmp_l_rn, // imm, rn or rn, rn
    daa, das, // rn
    dec_b, dec_w, dec_l, // {,[12],[12]}, rn
    divxs_b, divxs_w, divxu_b, divxu_w, // rn, rn
    eepmov_b, eepmov_w,
    exts_w, exts_l, extu_w, extu_l, // rn
    inc_b, inc_w, inc_l, // {,[12],[12]}, rn
    jmp_Mern, jmp_abs24, jmp_MMabs8, jsr_Mern, jsr_abs24, jsr_MMabs8,
    ldc_b_imm, ldc_b_rn, ldc_w_Mern, ldc_w_d16, ldc_w_d24, ldc_w_Mern_inc, ldc_w_abs16, ldc_w_abs24, // <operand>, ccr

    mov_b_rn_rn, mov_w_rn_rn, mov_l_rn_rn,
    mov_b_imm_rn, mov_w_imm_rn, mov_l_imm_rn,
    mov_b_Mern_rn, mov_w_Mern_rn, mov_l_Mern_rn, mov_b_d16_rn, mov_w_d16_rn, mov_l_d16_rn,
    mov_b_d24_rn, mov_w_d24_rn, mov_l_d24_rn, mov_b_Mern_inc_rn, mov_w_Mern_inc_rn, mov_l_Mern_inc_rn,
    mov_b_abs8_rn, mov_b_abs16_rn, mov_w_abs16_rn, mov_l_abs16_rn, mov_b_abs24_rn, mov_w_abs24_rn, mov_l_abs24_rn,
    mov_b_rn_Mern, mov_w_rn_Mern, mov_l_rn_Mern, mov_b_rn_d16, mov_w_rn_d16, mov_l_rn_d16,
    mov_b_rn_d24, mov_w_rn_d24, mov_l_rn_d24, mov_b_rn_Mern_dec, mov_w_rn_Mern_dec, mov_l_rn_Mern_dec,
    mov_b_rn_abs8, mov_b_rn_abs16, mov_w_rn_abs16, mov_l_rn_abs16, mov_b_rn_abs24, mov_w_rn_abs24, mov_l_rn_abs24,

    movfpe, movtpe, // resp. abs16, rnhl and rnhl, abs16
    mulxs_b, mulxs_w, mulxu_b, mulxu_w, // rn, rn or rn, ern
    neg_b, neg_w, neg_l, // rn
    nop,
    not_b, not_w, not_l, // rn
    or_b_imm, or_w_imm, or_l_imm, or_b_rn, or_w_rn, or_l_rn, // imm, rn or rn, rn
    orc, // imm, ccr
    //pop_w, pop_l, push_w, push_l,
    rotl_b, rotl_w, rotl_l, rotr_b, rotr_w, rotr_l, // rn
    rotxl_b, rotxl_w, rotxl_l, rotxr_b, rotxr_w, rotxr_l, // rn
    rte, rts,
    shal_b, shal_w, shal_l, shar_b, shar_w, shar_l, // rn
    shll_b, shll_w, shll_l, shlr_b, shlr_w, shlr_l, // rn
    sleep,
    stc_b, // rn
    stc_w_Mern, stc_w_d16, stc_w_d24, stc_w_Mern_dec, stc_w_abs16, stc_w_abs24, // ccr, <operand>
    sub_w_imm, sub_l_imm, sub_b_rn, sub_w_rn, sub_l_rn, // imm, rn or rn, rn
    subs, // {1,2,4}, rn
    subx_imm, subx_rn, // imm, rn or rn, rn
    trapa, // imm2
    xor_b_imm, xor_w_imm, xor_l_imm, xor_b_rn, xor_w_rn, xor_l_rn, // imm, rn or rn, rn
    xorc, // imm, ccr

    pub fn size(self: Opcode) usize { // in words
        return switch (self) {
            .ldc_w_d24, .mov_l_d24_rn, .mov_l_rn_d24, .stc_w_d24 => 5,
            .ldc_w_abs24, .mov_b_d24_rn, .mov_w_d24_rn, .mov_l_abs24_rn,
                .mov_b_rn_d24, .mov_w_rn_d24, .mov_l_rn_abs24, .stc_w_abs24
                    => 4,
            .add_l_imm, .and_l_imm, .cmp_l_imm, .ldc_w_d16, .ldc_w_abs16,
                .mov_b_abs24_rn, .mov_w_abs24_rn, .mov_l_imm_rn, .mov_l_d16_rn,
                .mov_l_abs16_rn, .mov_b_rn_abs24, .mov_w_rn_abs24,
                .mov_l_rn_d16, .mov_l_rn_abs16, .or_l_imm, .stc_w_d16,
                .stc_w_abs16, .sub_l_imm, .xor_l_imm => 3,
            .add_w_imm, .and_w_imm, .and_l_rn, .bcc_pcrel16, .bsr_pcrel16,
                .band_Mern, .band_abs8, .bclr_imm_Mern, .bclr_imm_abs8,
                .bclr_rn_Mern, .bclr_rn_abs8, .biand_Mern, .biand_abs8,
                .bild_Mern, .bild_abs8, .bior_Mern, .bior_abs8,
                .bist_Mern, .bist_abs8,.bixor_Mern, .bixor_abs8,
                .bld_Mern, .bld_abs8, .bnot_imm_Mern, .bnot_imm_abs8,
                .bnot_rn_Mern, .bnot_rn_abs8, .bor_Mern, .bor_abs8,
                .bset_imm_Mern, .bset_imm_abs8, .bset_rn_Mern, .bset_rn_abs8,
                .bst_Mern, .bst_abs8, .btst_imm_Mern, .btst_imm_abs8,
                .btst_rn_Mern, .btst_rn_abs8, .bxor_Mern, .bxor_abs8,
                .cmp_w_imm, .divxs_b, .divxs_w, .eepmov_b, .eepmov_w,
                .jmp_abs24, .jsr_abs24, .ldc_w_Mern, .ldc_w_Mern_inc,
                .mov_b_d16_rn, .mov_b_abs16_rn, .mov_w_imm_rn, .mov_w_d16_rn,
                .mov_w_abs16_rn, .mov_l_Mern_rn, .mov_l_Mern_inc_rn,
                .mov_b_rn_d16, .mov_b_rn_abs16, .mov_w_rn_d16, .mov_w_rn_abs16,
                .mov_l_rn_Mern, .mov_l_rn_Mern_dec, .movfpe, .movtpe,
                .mulxs_b, .mulxs_w, .or_w_imm, .or_l_rn,
                .stc_w_Mern, .stc_w_Mern_dec, .sub_w_imm, .xor_w_imm, .xor_l_rn
                    => 2,
            else => 1
        };
    }
};
pub const Insn = union(Opcode) {
    add_b_imm: struct { a: u8 , b: OpRnHL },
    add_w_imm: struct { a: u16, b: OpRn   },
    add_l_imm: struct { a: u32, b: OpERn  },
    add_b_rn: struct { a: OpRnHL, b: OpRnHL },
    add_w_rn: struct { a: OpRn  , b: OpRn   },
    add_l_rn: struct { a: OpERn , b: OpERn  },
    adds: struct { a: I124, b: OpERn },
    addx_imm: struct { a: u8, b: OpRnHL },
    addx_rn: struct { a: OpRnHL, b: OpRnHL },

    and_b_imm: struct { a: u8 , b: OpRnHL },
    and_w_imm: struct { a: u16, b: OpRn   },
    and_l_imm: struct { a: u32, b: OpERn  },
    and_b_rn: struct { a: OpRnHL, b: OpRnHL },
    and_w_rn: struct { a: OpRn  , b: OpRn   },
    and_l_rn: struct { a: OpERn , b: OpERn  },
    andc: u8, // b: ccr (implicit)

    bcc_pcrel8 : struct { cc: CCode, a: u8 }, // u8 because it's -126..+128 instead of -128..+127
    bcc_pcrel16: struct { cc: CCode, a: u16},
    bsr_pcrel8 : u8 , // u8 because it's -126..+128 instead of -128..+127
    bsr_pcrel16: u16,

    band_rn: struct { a: u3, b: OpRnHL },
    band_Mern: struct { a: u3, b: OpERn },
    band_abs8: struct { a: u3, b: u8 },
    bclr_imm_rn: struct { a: u3, b: OpRnHL },
    bclr_imm_Mern: struct { a: u3, b: OpERn },
    bclr_imm_abs8: struct { a: u3, b: u8 },
    bclr_rn_rn: struct { a: OpRnHL, b: OpRnHL },
    bclr_rn_Mern: struct { a: OpRnHL, b: OpERn },
    bclr_rn_abs8: struct { a: OpRnHL, b: u8 },
    biand_rn: struct { a: u3, b: OpRnHL },
    biand_Mern: struct { a: u3, b: OpERn  },
    biand_abs8: struct { a: u3, b: u8     },
    bild_rn: struct { a: u3, b: OpRnHL },
    bild_Mern: struct { a: u3, b: OpERn  },
    bild_abs8: struct { a: u3, b: u8     },
    bior_rn: struct { a: u3, b: OpRnHL },
    bior_Mern: struct { a: u3, b: OpERn  },
    bior_abs8: struct { a: u3, b: u8     },
    bist_rn: struct { a: u3, b: OpRnHL },
    bist_Mern: struct { a: u3, b: OpERn  },
    bist_abs8: struct { a: u3, b: u8     },
    bixor_rn: struct { a: u3, b: OpRnHL },
    bixor_Mern: struct { a: u3, b: OpERn  },
    bixor_abs8: struct { a: u3, b: u8     },
    bld_rn: struct { a: u3, b: OpRnHL },
    bld_Mern: struct { a: u3, b: OpERn  },
    bld_abs8: struct { a: u3, b: u8     },
    bnot_imm_rn: struct { a: u3, b: OpRnHL },
    bnot_imm_Mern: struct { a: u3, b: OpERn },
    bnot_imm_abs8: struct { a: u3, b: u8 },
    bnot_rn_rn: struct { a: OpRnHL, b: OpRnHL },
    bnot_rn_Mern: struct { a: OpRnHL, b: OpERn },
    bnot_rn_abs8: struct { a: OpRnHL, b: u8 },
    bor_rn: struct { a: u3, b: OpRnHL },
    bor_Mern: struct { a: u3, b: OpERn  },
    bor_abs8: struct { a: u3, b: u8     },
    bset_imm_rn: struct { a: u3, b: OpRnHL },
    bset_imm_Mern: struct { a: u3, b: OpERn },
    bset_imm_abs8: struct { a: u3, b: u8 },
    bset_rn_rn: struct { a: OpRnHL, b: OpRnHL },
    bset_rn_Mern: struct { a: OpRnHL, b: OpERn },
    bset_rn_abs8: struct { a: OpRnHL, b: u8 },
    bst_rn: struct { a: u3, b: OpRnHL },
    bst_Mern: struct { a: u3, b: OpERn  },
    bst_abs8: struct { a: u3, b: u8     },
    btst_imm_rn: struct { a: u3, b: OpRnHL },
    btst_imm_Mern: struct { a: u3, b: OpERn },
    btst_imm_abs8: struct { a: u3, b: u8 },
    btst_rn_rn: struct { a: OpRnHL, b: OpRnHL },
    btst_rn_Mern: struct { a: OpRnHL, b: OpERn },
    btst_rn_abs8: struct { a: OpRnHL, b: u8 },
    bxor_rn: struct { a: u3, b: OpRnHL },
    bxor_Mern: struct { a: u3, b: OpERn  },
    bxor_abs8: struct { a: u3, b: u8     },

    cmp_b_imm: struct { a: u8 , b: OpRnHL },
    cmp_w_imm: struct { a: u16, b: OpRn   },
    cmp_l_imm: struct { a: u32, b: OpERn  },
    cmp_b_rn : struct { a: OpRnHL, b: OpRnHL },
    cmp_w_rn : struct { a: OpRn  , b: OpRn   },
    cmp_l_rn : struct { a: OpERn , b: OpERn  },

    daa: OpRnHL,
    das: OpRnHL,

    dec_b: OpRnHL,
    dec_w: struct { a: I12, b: OpRn  },
    dec_l: struct { a: I12, b: OpERn },

    divxs_b: struct { a: OpRnHL, b: OpRn  },
    divxs_w: struct { a: OpRn  , b: OpERn },
    divxu_b: struct { a: OpRnHL, b: OpRn  },
    divxu_w: struct { a: OpRn  , b: OpERn },

    eepmov_b: void, eepmov_w: void,

    exts_w: OpRn, exts_l: OpERn, extu_w: OpRn, extu_l: OpERn,

    inc_b: OpRnHL,
    inc_w: struct { a: I12, b: OpRn  },
    inc_l: struct { a: I12, b: OpERn },

    jmp_Mern: OpERn, jmp_abs24: u24, jmp_MMabs8: u8,
    jsr_Mern: OpERn, jsr_abs24: u24, jsr_MMabs8: u8,

    ldc_b_imm: u8    , // ,ccr
    ldc_b_rn : OpRnHL, // ,ccr
    ldc_w_Mern: OpERn, // ,ccr
    ldc_w_d16: struct { a: u16, b: OpERn }, // ,ccr
    ldc_w_d24: struct { a: u24, b: OpERn }, // ,ccr
    ldc_w_Mern_inc: OpERn, // ,ccr
    ldc_w_abs16: u16, // ,ccr
    ldc_w_abs24: u24, // ,ccr

    mov_b_rn_rn: struct { a: OpRnHL, b: OpRnHL },
    mov_w_rn_rn: struct { a: OpRn  , b: OpRn   },
    mov_l_rn_rn: struct { a: OpERn , b: OpERn  },

    mov_b_imm_rn: struct { a: u8 , b: OpRnHL },
    mov_w_imm_rn: struct { a: u16, b: OpRn   },
    mov_l_imm_rn: struct { a: u32, b: OpERn  },
    mov_b_Mern_rn: struct { a: OpERn, b: OpRnHL },
    mov_w_Mern_rn: struct { a: OpERn, b: OpRn   },
    mov_l_Mern_rn: struct { a: OpERn, b: OpERn  },
    mov_b_d16_rn: struct { a1: u16, a2: OpERn, b: OpRnHL },
    mov_w_d16_rn: struct { a1: u16, a2: OpERn, b: OpRn   },
    mov_l_d16_rn: struct { a1: u16, a2: OpERn, b: OpERn  },
    mov_b_d24_rn: struct { a1: u24, a2: OpERn, b: OpRnHL },
    mov_w_d24_rn: struct { a1: u24, a2: OpERn, b: OpRn   },
    mov_l_d24_rn: struct { a1: u24, a2: OpERn, b: OpERn  },
    mov_b_Mern_inc_rn: struct { a: OpERn, b: OpRnHL },
    mov_w_Mern_inc_rn: struct { a: OpERn, b: OpRn   },
    mov_l_Mern_inc_rn: struct { a: OpERn, b: OpERn  },
    mov_b_abs8_rn : struct { a: u8 , b: OpRnHL },
    mov_b_abs16_rn: struct { a: u16, b: OpRnHL },
    mov_w_abs16_rn: struct { a: u16, b: OpRn   },
    mov_l_abs16_rn: struct { a: u16, b: OpERn  },
    mov_b_abs24_rn: struct { a: u24, b: OpRnHL },
    mov_w_abs24_rn: struct { a: u24, b: OpRn   },
    mov_l_abs24_rn: struct { a: u24, b: OpERn  },

    mov_b_rn_Mern: struct { a: OpRnHL, b: OpERn },
    mov_w_rn_Mern: struct { a: OpRn  , b: OpERn },
    mov_l_rn_Mern: struct { a: OpERn , b: OpERn },
    mov_b_rn_d16: struct { a: OpRnHL, b1: u16, b2: OpERn },
    mov_w_rn_d16: struct { a: OpRn  , b1: u16, b2: OpERn },
    mov_l_rn_d16: struct { a: OpERn , b1: u16, b2: OpERn },
    mov_b_rn_d24: struct { a: OpRnHL, b1: u24, b2: OpERn },
    mov_w_rn_d24: struct { a: OpRn  , b1: u24, b2: OpERn },
    mov_l_rn_d24: struct { a: OpERn , b1: u24, b2: OpERn },
    mov_b_rn_Mern_dec: struct { a: OpRnHL, b: OpERn },
    mov_w_rn_Mern_dec: struct { a: OpRn  , b: OpERn },
    mov_l_rn_Mern_dec: struct { a: OpERn , b: OpERn },
    mov_b_rn_abs8 : struct { a: OpRnHL, b: u8  },
    mov_b_rn_abs16: struct { a: OpRnHL, b: u16 },
    mov_w_rn_abs16: struct { a: OpRn  , b: u16 },
    mov_l_rn_abs16: struct { a: OpERn , b: u16 },
    mov_b_rn_abs24: struct { a: OpRnHL, b: u24 },
    mov_w_rn_abs24: struct { a: OpRn  , b: u24 },
    mov_l_rn_abs24: struct { a: OpERn , b: u24 },

    movfpe: struct { a: u16, b: OpRnHL },
    movtpe: struct { a: OpRnHL, b: u16 },
    mulxs_b: struct { a: OpRnHL, b: OpRn  },
    mulxs_w: struct { a: OpRn  , b: OpERn },
    mulxu_b: struct { a: OpRnHL, b: OpRn  },
    mulxu_w: struct { a: OpRn  , b: OpERn },
    neg_b: OpRnHL, neg_w: OpRn, neg_l: OpERn,
    nop: void,
    not_b: OpRnHL, not_w: OpRn, not_l: OpERn,

    or_b_imm: struct { a: u8 , b: OpRnHL },
    or_w_imm: struct { a: u16, b: OpRn   },
    or_l_imm: struct { a: u32, b: OpERn  },
    or_b_rn: struct { a: OpRnHL, b: OpRnHL },
    or_w_rn: struct { a: OpRn  , b: OpRn   },
    or_l_rn: struct { a: OpERn , b: OpERn  },
    orc: u8, // b: ccr (implicit)

    //pop_w: OpRn, pop_l: OpERn, push_w: OpRn, push_l: OpERn,

    rotl_b: OpRnHL, rotl_w: OpRn, rotl_l: OpERn,
    rotr_b: OpRnHL, rotr_w: OpRn, rotr_l: OpERn,
    rotxl_b: OpRnHL, rotxl_w: OpRn, rotxl_l: OpERn,
    rotxr_b: OpRnHL, rotxr_w: OpRn, rotxr_l: OpERn,
    rte: void, rts: void,
    shal_b: OpRnHL, shal_w: OpRn, shal_l: OpERn,
    shar_b: OpRnHL, shar_w: OpRn, shar_l: OpERn,
    shll_b: OpRnHL, shll_w: OpRn, shll_l: OpERn,
    shlr_b: OpRnHL, shlr_w: OpRn, shlr_l: OpERn,
    sleep: void,
    stc_b: OpRnHL, // a: ccr (implicit)
    stc_w_Mern: OpERn,
    stc_w_d16: struct { a: u16, b: OpERn },
    stc_w_d24: struct { a: u24, b: OpERn },
    stc_w_Mern_dec: OpERn,
    stc_w_abs16: u16,
    stc_w_abs24: u24,

    sub_w_imm: struct { a: u16, b: OpRn   },
    sub_l_imm: struct { a: u32, b: OpERn  },
    sub_b_rn: struct { a: OpRnHL, b: OpRnHL },
    sub_w_rn: struct { a: OpRn  , b: OpRn   },
    sub_l_rn: struct { a: OpERn , b: OpERn  },
    subs: struct { a: I124, b: OpERn },
    subx_imm: struct { a: u8, b: OpRnHL },
    subx_rn: struct { a: OpRnHL, b: OpRnHL },

    trapa: u2, // vector number

    xor_b_imm: struct { a: u8 , b: OpRnHL },
    xor_w_imm: struct { a: u16, b: OpRn   },
    xor_l_imm: struct { a: u32, b: OpERn  },
    xor_b_rn: struct { a: OpRnHL, b: OpRnHL },
    xor_w_rn: struct { a: OpRn  , b: OpRn   },
    xor_l_rn: struct { a: OpERn , b: OpERn  },
    xorc: u8, // b: ccr (implicit)

    pub inline fn size(self: Insn) usize { // in words
        return Opcode.size(@as(Opcode, self));
    }

    inline fn cc(x: CCode) []const u8 {
        const lut = [_][]const u8 {
            "ra","rn","hi","ls","cc","cs","ne","eq",
            "vc","vs","pl","mi","ge","lt","gt","le"
        };
        return lut[@enumToInt(x)];
    }
    inline fn rnhl(x: OpRnHL) []const u8 {
        const lut = [_][]const u8 {
            "r0h","r1h","r2h","r3h","r4h","r5h","r6h","r7h",
            "r0l","r1l","r2l","r3l","r4l","r5l","r6l","r7l"
        };
        return lut[@enumToInt(x)];
    }
    inline fn rn(x: OpRn) []const u8 {
        const lut = [_][]const u8 {
            "r0","r1","r2","r3","r4","r5","r6","r7",
            "e0","e1","e2","e3","e4","e5","e6","e7"
        };
        return lut[@enumToInt(x)];
    }
    inline fn ern(x: OpERn) []const u8 {
        const lut = [_][]const u8 {
            "er0","er1","er2","er3","er4","er5","er6","er7"
        };
        return lut[@enumToInt(x)];
    }
    fn D(x: anytype)
            (if (@as(std.builtin.TypeId, @typeInfo(@TypeOf(x))) == .Int)
                @TypeOf(x)
             else []const u8) {
        return if (@TypeOf(x) == CCode) cc(x)
        else if (@TypeOf(x) == OpRnHL) rnhl(x)
        else if (@TypeOf(x) == OpRn) rn(x)
        else if (@TypeOf(x) == OpERn) ern(x)
        else if (@TypeOf(x) == I124) switch(x) {
            .one => "1", .two => "2", .four => "4"
        } else if (@TypeOf(x) == I12) switch(x) {
            .one => "1", .two => "2"
        } else if (@as(std.builtin.TypeId, @typeInfo(@TypeOf(x))) == .Int) {
            return x;
        } else {
            print("{}\n", .{x});
            @panic("no!");
        };
    }

    pub fn display(self: Insn) void {
        switch (self) {
            .add_b_imm => |d| print("add.b #H'{X:2}, {}\n", .{d.a,D(d.b)}),
            .add_w_imm => |d| print("add.w #H'{X:4}, {}\n", .{d.a,D(d.b)}),
            .add_l_imm => |d| print("add.l #H'{X:8}, {}\n", .{d.a,D(d.b)}),
            .add_b_rn => |d| print("add.b {}, {}\n", .{D(d.a),D(d.b)}),
            .add_w_rn => |d| print("add.w {}, {}\n", .{D(d.a),D(d.b)}),
            .add_l_rn => |d| print("add.l {}, {}\n", .{D(d.a),D(d.b)}),
            .adds => |d| print("adds #{}, {}\n", .{D(d.a),D(d.b)}),
            .addx_imm => |d| print("addx #H'{X:2}, {}\n", .{d.a,D(d.b)}),
            .addx_rn => |d| print("addx {}, {}\n", .{D(d.a),D(d.b)}),

            .and_b_imm => |d| print("and.b #H'{X:2}, {}\n", .{d.a,D(d.b)}),
            .and_w_imm => |d| print("and.w #H'{X:4}, {}\n", .{d.a,D(d.b)}),
            .and_l_imm => |d| print("and.l #H'{X:8}, {}\n", .{d.a,D(d.b)}),
            .and_b_rn => |d| print("and.b {}, {}\n", .{D(d.a),D(d.b)}),
            .and_w_rn => |d| print("and.w {}, {}\n", .{D(d.a),D(d.b)}),
            .and_l_rn => |d| print("and.l {}, {}\n", .{D(d.a),D(d.b)}),
            .andc => |imm| print("andc #H'{X:2}, ccr\n", .{imm}),

            .bcc_pcrel8 => |d| print("b{} +H'{X:2}\n", .{D(d.cc), d.a}),
            .bcc_pcrel16=> |d| print("b{} +H'{X:4}\n", .{D(d.cc), d.a}),
            .bsr_pcrel8 => |d| print("bsr +H'{X:2}\n", .{d}),
            .bsr_pcrel16=> |d| print("bsr +H'{X:4}\n", .{d}),

            .band_rn => |d| print("band #{}, {}\n", .{d.a, D(d.b)}),
            .band_Mern => |d| print("band #{}, @{}\n", .{d.a, D(d.b)}),
            .band_abs8 => |d| print("band #{}, @H'{X:2}\n", .{d.a, D(d.b)}),
            .bld_rn => |d| print("bld #{}, {}\n", .{d.a, D(d.b)}),
            .bld_Mern => |d| print("bld #{}, @{}\n", .{d.a, D(d.b)}),
            .bld_abs8 => |d| print("bld #{}, @H'{X:2}\n", .{d.a, d.b}),
            .bor_rn => |d| print("bor #{}, {}\n", .{d.a, D(d.b)}),
            .bor_Mern => |d| print("bor #{}, @{}\n", .{d.a, D(d.b)}),
            .bor_abs8 => |d| print("bor #{}, @H'{X:2}\n", .{d.a, d.b}),
            .bst_rn => |d| print("bst #{}, {}\n", .{d.a, D(d.b)}),
            .bst_Mern => |d| print("bst #{}, @{}\n", .{d.a, D(d.b)}),
            .bst_abs8 => |d| print("bst #{}, @H'{X:2}\n", .{d.a, d.b}),
            .bxor_rn => |d| print("bxor #{}, {}\n", .{d.a, D(d.b)}),
            .bxor_Mern => |d| print("bxor #{}, @{}\n", .{d.a, D(d.b)}),
            .bxor_abs8 => |d| print("bxor #{}, @H'{X:2}\n", .{d.a, d.b}),
            .biand_rn => |d| print("biand #{}, {}\n", .{d.a, D(d.b)}),
            .biand_Mern => |d| print("biand #{}, @{}\n", .{d.a, D(d.b)}),
            .biand_abs8 => |d| print("biand #{}, @H'{X:2}\n", .{d.a, d.b}),
            .bild_rn => |d| print("bild #{}, {}\n", .{d.a, D(d.b)}),
            .bild_Mern => |d| print("bild #{}, @{}\n", .{d.a, D(d.b)}),
            .bild_abs8 => |d| print("bild #{}, @H'{X:2}\n", .{d.a, d.b}),
            .bior_rn => |d| print("bior #{}, {}\n", .{d.a, D(d.b)}),
            .bior_Mern => |d| print("bior #{}, @{}\n", .{d.a, D(d.b)}),
            .bior_abs8 => |d| print("bior #{}, @H'{X:2}\n", .{d.a, d.b}),
            .bist_rn => |d| print("bist #{}, {}\n", .{d.a, D(d.b)}),
            .bist_Mern => |d| print("bist #{}, @{}\n", .{d.a, D(d.b)}),
            .bist_abs8 => |d| print("bist #{}, @H'{X:2}\n", .{d.a, d.b}),
            .bixor_rn => |d| print("bixor #{}, {}\n", .{d.a, D(d.b)}),
            .bixor_Mern => |d| print("bixor #{}, @{}\n", .{d.a, D(d.b)}),
            .bixor_abs8 => |d| print("bixor #{}, @H'{X:2}\n", .{d.a, d.b}),

            .bclr_imm_rn => |d| print("bclr #{}, {}\n", .{d.a, D(d.b)}),
            .bclr_imm_Mern => |d| print("bclr #{}, @{}\n", .{d.a, D(d.b)}),
            .bclr_imm_abs8 => |d| print("bclr #{}, @H'{X:2}\n", .{d.a, D(d.b)}),
            .bclr_rn_rn => |d| print("bclr #{}, {}\n", .{D(d.a), D(d.b)}),
            .bclr_rn_Mern => |d| print("bclr {}, @{}\n", .{D(d.a), D(d.b)}),
            .bclr_rn_abs8 => |d| print("bclr {}, @H'{X:2}\n", .{D(d.a), D(d.b)}),
            .bnot_imm_rn => |d| print("bnot #{}, {}\n", .{d.a, D(d.b)}),
            .bnot_imm_Mern => |d| print("bnot #{}, @{}\n", .{d.a, D(d.b)}),
            .bnot_imm_abs8 => |d| print("bnot #{}, @H'{X:2}\n", .{d.a, D(d.b)}),
            .bnot_rn_rn => |d| print("bnot #{}, {}\n", .{D(d.a), D(d.b)}),
            .bnot_rn_Mern => |d| print("bnot {}, @{}\n", .{D(d.a), D(d.b)}),
            .bnot_rn_abs8 => |d| print("bnot {}, @H'{X:2}\n", .{D(d.a), D(d.b)}),
            .bset_imm_rn => |d| print("bset #{}, {}\n", .{d.a, D(d.b)}),
            .bset_imm_Mern => |d| print("bset #{}, @{}\n", .{d.a, D(d.b)}),
            .bset_imm_abs8 => |d| print("bset #{}, @H'{X:2}\n", .{d.a, D(d.b)}),
            .bset_rn_rn => |d| print("bset #{}, {}\n", .{D(d.a), D(d.b)}),
            .bset_rn_Mern => |d| print("bset {}, @{}\n", .{D(d.a), D(d.b)}),
            .bset_rn_abs8 => |d| print("bset {}, @H'{X:2}\n", .{D(d.a), D(d.b)}),
            .btst_imm_rn => |d| print("btst #{}, {}\n", .{d.a, D(d.b)}),
            .btst_imm_Mern => |d| print("btst #{}, @{}\n", .{d.a, D(d.b)}),
            .btst_imm_abs8 => |d| print("btst #{}, @H'{X:2}\n", .{d.a, D(d.b)}),
            .btst_rn_rn => |d| print("btst #{}, {}\n", .{D(d.a), D(d.b)}),
            .btst_rn_Mern => |d| print("btst {}, @{}\n", .{D(d.a), D(d.b)}),
            .btst_rn_abs8 => |d| print("btst {}, @H'{X:2}\n", .{D(d.a), D(d.b)}),

            .cmp_b_imm => |d| print("cmp.b #H'{X:2}, {}\n", .{D(d.a), D(d.b)}),
            .cmp_w_imm => |d| print("cmp.w #H'{X:4}, {}\n", .{D(d.a), D(d.b)}),
            .cmp_l_imm => |d| print("cmp.l #H'{X:8}, {}\n", .{D(d.a), D(d.b)}),
            .cmp_b_rn => |d| print("cmp.b {}, {}\n", .{D(d.a), D(d.b)}),
            .cmp_w_rn => |d| print("cmp.w {}, {}\n", .{D(d.a), D(d.b)}),
            .cmp_l_rn => |d| print("cmp.l {}, {}\n", .{D(d.a), D(d.b)}),

            .daa => |d| print("daa {}\n", .{D(d)}),
            .das => |d| print("das {}\n", .{D(d)}),

            .dec_b => |d| print("dec.b {}\n", .{D(d)}),
            .dec_w => |d| print("dec.w #{}, {}\n", .{D(d.a), D(d.b)}),
            .dec_l => |d| print("dec.l #{}, {}\n", .{D(d.a), D(d.b)}),

            .divxs_b => |d| print("divxs.b {}, {}\n", .{D(d.a), D(d.b)}),
            .divxs_w => |d| print("divxs.w {}, {}\n", .{D(d.a), D(d.b)}),
            .divxu_b => |d| print("divxu.b {}, {}\n", .{D(d.a), D(d.b)}),
            .divxu_w => |d| print("divxu.w {}, {}\n", .{D(d.a), D(d.b)}),

            .eepmov_b => print("eepmov.b\n", .{}),
            .eepmov_w => print("eepmov.w\n", .{}),

            .exts_w => |d| print("exts.w {}\n", .{D(d)}),
            .exts_l => |d| print("exts.l {}\n", .{D(d)}),
            .extu_w => |d| print("extu.w {}\n", .{D(d)}),
            .extu_l => |d| print("extu.l {}\n", .{D(d)}),

            .inc_b => |d| print("inc.b {}\n", .{D(d)}),
            .inc_w => |d| print("inc.w #{}, {}\n", .{D(d.a), D(d.b)}),
            .inc_l => |d| print("inc.l #{}, {}\n", .{D(d.a), D(d.b)}),

            .jmp_Mern => |d| print("jmp @{}\n", .{D(d)}),
            .jmp_abs24 => |d| print("jmp H'{X:6}\n", .{D(d)}),
            .jmp_MMabs8 => |d| print("jmp @@{X:2}\n", .{D(d)}),
            .jsr_Mern => |d| print("jsr @{}\n", .{D(d)}),
            .jsr_abs24 => |d| print("jsr H'{X:6}\n", .{D(d)}),
            .jsr_MMabs8 => |d| print("jsr @@{X:2}\n", .{D(d)}),

            .ldc_b_imm => |d| print("ldc.b #H'{X:2}, ccr\n", .{D(d)}),
            .ldc_b_rn => |d| print("ldc.b {}, ccr\n", .{D(d)}),
            .ldc_w_Mern => |d| print("ldc.w @{}, ccr\n", .{D(d)}),
            .ldc_w_d16 => |d| print("ldc.w @(H'{X:4},{}), ccr\n", .{D(d.a), D(d.b)}),
            .ldc_w_d24 => |d| print("ldc.w @(H'{X:6},{}), ccr\n", .{D(d.a), D(d.b)}),
            .ldc_w_Mern_inc => |d| print("ldc.w @{}+, ccr\n", .{D(d)}),
            .ldc_w_abs16 => |d| print("ldc.w @H'{X:4}, ccr\n", .{D(d)}),
            .ldc_w_abs24 => |d| print("ldc.w @H'{X:6}, ccr\n", .{D(d)}),

            .mov_b_rn_rn => |d| print("mov.b {}, {}\n", .{D(d.a), D(d.b)}),
            .mov_w_rn_rn => |d| print("mov.w {}, {}\n", .{D(d.a), D(d.b)}),
            .mov_l_rn_rn => |d| print("mov.l {}, {}\n", .{D(d.a), D(d.b)}),
            .mov_b_imm_rn => |d| print("mov.b #H'{X:2} {}\n", .{D(d.a), D(d.b)}),
            .mov_w_imm_rn => |d| print("mov.w #H'{X:2} {}\n", .{D(d.a), D(d.b)}),
            .mov_l_imm_rn => |d| print("mov.l #H'{X:2} {}\n", .{D(d.a), D(d.b)}),

            .mov_b_Mern_rn => |d| print("mov.b @{}, {}\n", .{D(d.a), D(d.b)}),
            .mov_w_Mern_rn => |d| print("mov.w @{}, {}\n", .{D(d.a), D(d.b)}),
            .mov_l_Mern_rn => |d| print("mov.l @{}, {}\n", .{D(d.a), D(d.b)}),
            .mov_b_d16_rn => |d| print("mov.b @(H'{X:4}, {}), {}\n", .{D(d.a1), D(d.a2), D(d.b)}),
            .mov_w_d16_rn => |d| print("mov.w @(H'{X:4}, {}), {}\n", .{D(d.a1), D(d.a2), D(d.b)}),
            .mov_l_d16_rn => |d| print("mov.l @(H'{X:4}, {}), {}\n", .{D(d.a1), D(d.a2), D(d.b)}),
            .mov_b_d24_rn => |d| print("mov.b @(H'{X:6}, {}), {}\n", .{D(d.a1), D(d.a2), D(d.b)}),
            .mov_w_d24_rn => |d| print("mov.w @(H'{X:6}, {}), {}\n", .{D(d.a1), D(d.a2), D(d.b)}),
            .mov_l_d24_rn => |d| print("mov.l @(H'{X:6}, {}), {}\n", .{D(d.a1), D(d.a2), D(d.b)}),
            .mov_b_Mern_inc_rn => |d| print("mov.b @{}+, {}\n", .{D(d.a), D(d.b)}),
            .mov_w_Mern_inc_rn => |d|
                if (d.a == .er7)  print("pop.l {}\n", .{D(d.b)})
                else print("mov.w @{}+, {}\n", .{D(d.a), D(d.b)}),
            .mov_l_Mern_inc_rn => |d|
                if (d.a == .er7)  print("pop.l {}\n", .{D(d.b)})
                else print("mov.l @{}+, {}\n", .{D(d.a), D(d.b)}),
            .mov_b_abs8_rn => |d| print("mov.b @H'{X:2}, {}\n", .{D(d.a), D(d.b)}),
            .mov_b_abs16_rn => |d| print("mov.b @H'{X:4}, {}\n", .{D(d.a), D(d.b)}),
            .mov_w_abs16_rn => |d| print("mov.w @H'{X:4}, {}\n", .{D(d.a), D(d.b)}),
            .mov_l_abs16_rn => |d| print("mov.l @H'{X:4}, {}\n", .{D(d.a), D(d.b)}),
            .mov_b_abs24_rn => |d| print("mov.b @H'{X:6}, {}\n", .{D(d.a), D(d.b)}),
            .mov_w_abs24_rn => |d| print("mov.w @H'{X:6}, {}\n", .{D(d.a), D(d.b)}),
            .mov_l_abs24_rn => |d| print("mov.l @H'{X:6}, {}\n", .{D(d.a), D(d.b)}),

            .mov_b_rn_Mern => |d| print("mov.b {}, @{}\n", .{D(d.a), D(d.b)}),
            .mov_w_rn_Mern => |d| print("mov.w {}, @{}\n", .{D(d.a), D(d.b)}),
            .mov_l_rn_Mern => |d| print("mov.l {}, @{}\n", .{D(d.a), D(d.b)}),
            .mov_b_rn_d16 => |d| print("mov.b {}, @(H'{X:4}, {})\n", .{D(d.a), D(d.b1), D(d.b2)}),
            .mov_w_rn_d16 => |d| print("mov.w {}, @(H'{X:4}, {})\n", .{D(d.a), D(d.b1), D(d.b2)}),
            .mov_l_rn_d16 => |d| print("mov.l {}, @(H'{X:4}, {})\n", .{D(d.a), D(d.b1), D(d.b2)}),
            .mov_b_rn_d24 => |d| print("mov.b {}, @(H'{X:6}, {})\n", .{D(d.a), D(d.b1), D(d.b2)}),
            .mov_w_rn_d24 => |d| print("mov.w {}, @(H'{X:6}, {})\n", .{D(d.a), D(d.b1), D(d.b2)}),
            .mov_l_rn_d24 => |d| print("mov.l {}, @(H'{X:6}, {})\n", .{D(d.a), D(d.b1), D(d.b2)}),
            .mov_b_rn_Mern_dec => |d| print("mov.b {}, @-{}\n", .{D(d.a), D(d.b)}),
            .mov_w_rn_Mern_dec => |d|
                if (d.b == .er7)  print("push.w {}\n", .{D(d.a)})
                else print("mov.w {}, @-{}\n", .{D(d.a), D(d.b)}),
            .mov_l_rn_Mern_dec => |d|
                if (d.b == .er7)  print("push.l {}\n", .{D(d.a)})
                else print("mov.l {}, @-{}\n", .{D(d.a), D(d.b)}),
            .mov_b_rn_abs8 => |d| print("mov.b {}, @H'{X:2}\n", .{D(d.a), D(d.b)}),
            .mov_b_rn_abs16 => |d| print("mov.b {}, @H'{X:4}\n", .{D(d.a), D(d.b)}),
            .mov_w_rn_abs16 => |d| print("mov.w {}, @H'{X:4}\n", .{D(d.a), D(d.b)}),
            .mov_l_rn_abs16 => |d| print("mov.l {}, @H'{X:4}\n", .{D(d.a), D(d.b)}),
            .mov_b_rn_abs24 => |d| print("mov.b {}, @H'{X:6}\n", .{D(d.a), D(d.b)}),
            .mov_w_rn_abs24 => |d| print("mov.w {}, @H'{X:6}\n", .{D(d.a), D(d.b)}),
            .mov_l_rn_abs24 => |d| print("mov.l {}, @H'{X:6}\n", .{D(d.a), D(d.b)}),

            .movfpe => |d| print("movfpe H'{X:4}, {}\n", .{D(d.a), D(d.b)}),
            .movtpe => |d| print("movtpe {}, H'{X:4}\n", .{D(d.a), D(d.b)}),

            .mulxs_b => |d| print("mulxs.b {}, {}\n", .{D(d.a), D(d.b)}),
            .mulxs_w => |d| print("mulxs.w {}, {}\n", .{D(d.a), D(d.b)}),
            .mulxu_b => |d| print("mulxu.b {}, {}\n", .{D(d.a), D(d.b)}),
            .mulxu_w => |d| print("mulxu.w {}, {}\n", .{D(d.a), D(d.b)}),

            .neg_b => |d| print("neg.b {}\n", .{D(d)}),
            .neg_w => |d| print("neg.w {}\n", .{D(d)}),
            .neg_l => |d| print("neg.l {}\n", .{D(d)}),

            .nop => print("nop\n", .{}),

            .not_b => |d| print("not.b {}\n", .{D(d)}),
            .not_w => |d| print("not.w {}\n", .{D(d)}),
            .not_l => |d| print("not.l {}\n", .{D(d)}),

            .or_b_imm => |d| print("or.b #H'{X:2}, {}\n", .{d.a,D(d.b)}),
            .or_w_imm => |d| print("or.w #H'{X:4}, {}\n", .{d.a,D(d.b)}),
            .or_l_imm => |d| print("or.l #H'{X:8}, {}\n", .{d.a,D(d.b)}),
            .or_b_rn => |d| print("or.b {}, {}\n", .{D(d.a),D(d.b)}),
            .or_w_rn => |d| print("or.w {}, {}\n", .{D(d.a),D(d.b)}),
            .or_l_rn => |d| print("or.l {}, {}\n", .{D(d.a),D(d.b)}),
            .orc => |imm| print("orc #H'{X:2}, ccr\n", .{imm}),

            .rotl_b => |d| print("rotl.b {}\n", .{D(d)}),
            .rotl_w => |d| print("rotl.w {}\n", .{D(d)}),
            .rotl_l => |d| print("rotl.l {}\n", .{D(d)}),
            .rotr_b => |d| print("rotr.b {}\n", .{D(d)}),
            .rotr_w => |d| print("rotr.w {}\n", .{D(d)}),
            .rotr_l => |d| print("rotr.l {}\n", .{D(d)}),
            .rotxl_b => |d| print("rotxl.b {}\n", .{D(d)}),
            .rotxl_w => |d| print("rotxl.w {}\n", .{D(d)}),
            .rotxl_l => |d| print("rotxl.l {}\n", .{D(d)}),
            .rotxr_b => |d| print("rotxr.b {}\n", .{D(d)}),
            .rotxr_w => |d| print("rotxr.w {}\n", .{D(d)}),
            .rotxr_l => |d| print("rotxr.l {}\n", .{D(d)}),

            .rte => print("rte\n", .{}),
            .rts => print("rts\n", .{}),

            .shal_b => |d| print("shal.b {}\n", .{D(d)}),
            .shal_w => |d| print("shal.w {}\n", .{D(d)}),
            .shal_l => |d| print("shal.l {}\n", .{D(d)}),
            .shar_b => |d| print("shar.b {}\n", .{D(d)}),
            .shar_w => |d| print("shar.w {}\n", .{D(d)}),
            .shar_l => |d| print("shar.l {}\n", .{D(d)}),
            .shll_b => |d| print("shll.b {}\n", .{D(d)}),
            .shll_w => |d| print("shll.w {}\n", .{D(d)}),
            .shll_l => |d| print("shll.l {}\n", .{D(d)}),
            .shlr_b => |d| print("shlr.b {}\n", .{D(d)}),
            .shlr_w => |d| print("shlr.w {}\n", .{D(d)}),
            .shlr_l => |d| print("shlr.l {}\n", .{D(d)}),

            .sleep => print("sleep\n", .{}),

            .stc_b => |d| print("stc.b ccr, {}\n", .{D(d)}),
            .stc_w_Mern => |d| print("stc.w ccr, @{}\n", .{D(d)}),
            .stc_w_d16 => |d| print("stc.w ccr, @(H'{X:4},{})\n", .{D(d.a), D(d.b)}),
            .stc_w_d24 => |d| print("stc.w ccr, @(H'{X:6},{})\n", .{D(d.a), D(d.b)}),
            .stc_w_Mern_dec => |d| print("stc.w ccr, @-{}\n", .{D(d)}),
            .stc_w_abs16 => |d| print("stc.w ccr, @H'{X:4}\n", .{D(d)}),
            .stc_w_abs24 => |d| print("stc.w ccr, @H'{X:6}\n", .{D(d)}),

            .sub_w_imm => |d| print("sub.w #H'{X:4}, {}\n", .{d.a,D(d.b)}),
            .sub_l_imm => |d| print("sub.l #H'{X:8}, {}\n", .{d.a,D(d.b)}),
            .sub_b_rn => |d| print("sub.b {}, {}\n", .{D(d.a),D(d.b)}),
            .sub_w_rn => |d| print("sub.w {}, {}\n", .{D(d.a),D(d.b)}),
            .sub_l_rn => |d| print("sub.l {}, {}\n", .{D(d.a),D(d.b)}),
            .subs => |d| print("subs #{}, {}\n", .{D(d.a),D(d.b)}),
            .subx_imm => |d| print("subx #H'{X:2}, {}\n", .{d.a,D(d.b)}),
            .subx_rn => |d| print("subx {}, {}\n", .{D(d.a),D(d.b)}),

            .trapa => |d| print("trapa #{}\n", .{d}),

            .xor_b_imm => |d| print("xor.b #H'{X:2}, {}\n", .{d.a,D(d.b)}),
            .xor_w_imm => |d| print("xor.w #H'{X:4}, {}\n", .{d.a,D(d.b)}),
            .xor_l_imm => |d| print("xor.l #H'{X:8}, {}\n", .{d.a,D(d.b)}),
            .xor_b_rn => |d| print("xor.b {}, {}\n", .{D(d.a),D(d.b)}),
            .xor_w_rn => |d| print("xor.w {}, {}\n", .{D(d.a),D(d.b)}),
            .xor_l_rn => |d| print("xor.l {}, {}\n", .{D(d.a),D(d.b)}),
            .xorc => |imm| print("xorc #H'{X:2}, ccr\n", .{imm}),

            //else => print("<unknown> {}\n", .{@as(Opcode, self)})
        }
    }
};

// TODO
//pub const InsnTyp = enum {
//    add, adds, addx, sub, subs, subx, cmp,
//    and_, andc, or_, orc, xor, xorc,
//    band, bclr, biand, bild, bior, bist, bixor, bld, bnot, bor, bset, bst, btst, bxor,
//    bcc, bsr, jmp, jsr, rte, rts,
//    daa, das,
//    dec, inc,
//    divxs, divxu, mulxs, mulxu,
//    eepmov,
//    exts, extu,
//    ldc, stc,
//    mov, movfpe, movtpe,
//    neg, not,
//    nop,
//    pop, push,
//    rotl, rotr, rotxl, rotxr,
//    shal, shar, shll, shlr,
//    sleep,
//    trapa,
//};
//pub const OpLen = enum(u2) { none, b, w, l };
//pub const OpType = enum {
//    direct_rhl,
//    direct_rn,
//    direct_ern,
//    indir_ern,
//    indoff_ern,
//    indir_ern_postinc,
//    indir_ern_predec,
//    abs8,
//    abs16,
//    abs24,
//    imm8,
//    imm16,
//    imm32,
//    pcrel8,
//    pcrel16,
//    memind,
//    cc
//};
//pub const Operand = union(OpType) {
//    direct_rhl: OpRnHL,
//    direct_rn: OpRn,
//    direct_ern: OpERn,
//    indir_ern: OpERn,
//    indoff_ern: OpERn,
//    indir_ern_postinc: OpERn,
//    indir_ern_predec: OpERn,
//    abs8: u8,
//    abs16: u16,
//    abs24: u24,
//    imm8: u8,
//    imm16: u16,
//    imm32: u32,
//    pcrel8: u8,
//    pcrel16: u16,
//    memind: u8,
//    cc: CCode
//};
//pub const FlexInsn = struct {
//    op: InsnTyp,
//    len: OpLen,
//    ops: []Operand
//};

