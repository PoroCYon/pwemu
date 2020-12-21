
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

fn handle_add_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for add_b_imm\n", .{});
    insn.display();
}
fn handle_add_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for add_w_imm\n", .{});
    insn.display();
}
fn handle_add_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for add_l_imm\n", .{});
    insn.display();
}
fn handle_add_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for add_b_rn\n", .{});
    insn.display();
}
fn handle_add_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for add_w_rn\n", .{});
    insn.display();
}
fn handle_add_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for add_l_rn\n", .{});
    insn.display();
}
fn handle_adds(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for adds\n", .{});
    insn.display();
}
fn handle_addx_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for addx_imm\n", .{});
    insn.display();
}
fn handle_addx_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for addx_rn\n", .{});
    insn.display();
}
fn handle_and_b_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for and_b_imm\n", .{});
    insn.display();
}
fn handle_and_w_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for and_w_imm\n", .{});
    insn.display();
}
fn handle_and_l_imm(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for and_l_imm\n", .{});
    insn.display();
}
fn handle_and_b_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for and_b_rn\n", .{});
    insn.display();
}
fn handle_and_w_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for and_w_rn\n", .{});
    insn.display();
}
fn handle_and_l_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for and_l_rn\n", .{});
    insn.display();
}
fn handle_andc(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for andc\n", .{});
    insn.display();
}
fn handle_bcc_pcrel8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bcc_pcrel8\n", .{});
    insn.display();
}
fn handle_bcc_pcrel16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bcc_pcrel16\n", .{});
    insn.display();
}
fn handle_bsr_pcrel8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bsr_pcrel8\n", .{});
    insn.display();
}
fn handle_bsr_pcrel16(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bsr_pcrel16\n", .{});
    insn.display();
}
fn handle_band_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for band_rn\n", .{});
    insn.display();
}
fn handle_band_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for band_Mern\n", .{});
    insn.display();
}
fn handle_band_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for band_abs8\n", .{});
    insn.display();
}
fn handle_bclr_imm_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bclr_imm_rn\n", .{});
    insn.display();
}
fn handle_bclr_imm_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bclr_imm_Mern\n", .{});
    insn.display();
}
fn handle_bclr_imm_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bclr_imm_abs8\n", .{});
    insn.display();
}
fn handle_bclr_rn_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bclr_rn_rn\n", .{});
    insn.display();
}
fn handle_bclr_rn_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bclr_rn_Mern\n", .{});
    insn.display();
}
fn handle_bclr_rn_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bclr_rn_abs8\n", .{});
    insn.display();
}
fn handle_biand_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for biand_rn\n", .{});
    insn.display();
}
fn handle_biand_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for biand_Mern\n", .{});
    insn.display();
}
fn handle_biand_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for biand_abs8\n", .{});
    insn.display();
}
fn handle_bild_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bild_rn\n", .{});
    insn.display();
}
fn handle_bild_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bild_Mern\n", .{});
    insn.display();
}
fn handle_bild_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bild_abs8\n", .{});
    insn.display();
}
fn handle_bior_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bior_rn\n", .{});
    insn.display();
}
fn handle_bior_Mern(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bior_Mern\n", .{});
    insn.display();
}
fn handle_bior_abs8(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
    print("handler for bior_abs8\n", .{});
    insn.display();
}
fn handle_bist_rn(self: *H8300H, insn: Insn, oands: anytype, raw: []const u16) void {
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

    self.pc = @truncate(u16, self.pc + insn.size() * 2);
    self.cycle((insn.size()-1)*2);
    self.fetch = self.read16(self.pc - 2);
}

//    return switch ((fetch >> 12) & 0xf) {
//        0 => switch ((fetch >> 8) & 0xf) {
//            0 => .nop,
//            1 => switch ((fetch >> 4) & 0xf) {
//                0 => dec_mov(T, fetch, getwd, ud),
//                4 => dec_ldcstc(T, fetch, getwd, ud),
//                8 => .sleep,
//                0xc => if ((fetch & 0xf) == 0) blk: {
//                    const cd = getwd(ud);
//                    break :blk switch ((cd >> 8) & 0xff) {
//                        0x50, 0x52 => // TODO mulxs
//                        else => @panic("illegal insn!"),
//                    };
//                } else @panic("illegal insn!"),
//                0xd => if ((fetch & 0xf) == 0) blk: {
//                    const cd = getwd(ud);
//                    break :blk switch ((cd >> 8) & 0xff) {
//                        0x51, 0x53 => // TODO divxs
//                        else => @panic("illegal insn!"),
//                    };
//                } else @panic("illegal insn!"),
//                0xf => if ((fetch & 0xf) == 0) blk: {
//                    const cd = getwd(ud);
//                    break :blk switch ((cd >> 8) & 0xff) {
//                        0x64 => // TODO or
//                        0x65 => // TODO xor
//                        0x66 => // TODO and
//                        else => @panic("illegal insn!"),
//                    };
//                } else @panic("illegal insn!"),
//                else => @panic("illegal insn!"),
//            },
//            2 => dec_stc(T, fetch, getwd, ud),
//            3 => dec_ldc(T, fetch, getwd, ud),
//            4 => dec_org(T, fetch, getwd, ud),
//            5 => dec_xorg(T, fetch, getwd, ud),
//            6 => dec_andc(T, fetch, getwd, ud),
//            7 => dec_ldc(T, fetch, getwd, ud),
//            8, 9 => dec_add(T, fetch, getwd, ud),
//            0xa => switch ((fetch >> 4) & 0xf) {
//                0 => dec_inc(T, fetch, getwd, ud),
//                8..0xf => dec_add(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            0xb => switch ((fetch >> 4) & 0xf) {
//                0,8,9 => dec_adds(T, fetch, getwd, ud),
//                5,7,0xd,0xf => dec_inc(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            0xc,0xd => dec_mov(T, fetch, getwd, ud),
//            0xe => dec_addx(T, fetch, getwd, ud),
//            0xf => switch ((fetch >> 4) & 0xf) {
//                0 => dec_daa(T, fetch, getwd, ud),
//                8..0xf => dec_mov(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            else => @panic("wtf"),
//        },
//        1 => switch ((fetch >> 8) & 0xf) {
//            0 => switch ((fetch >> 4) & 0xf) {
//                0,1,3  => dec_shll(T, fetch, getwd, ud),
//                8,9,11 => dec_shal(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            1 => switch ((fetch >> 4) & 0xf) {
//                0,1,3  => dec_shlr(T, fetch, getwd, ud),
//                8,9,11 => dec_shar(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            2 => switch ((fetch >> 4) & 0xf) {
//                0,1,3  => dec_rotxl(T, fetch, getwd, ud),
//                8,9,11 => dec_rotl(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            3 => switch ((fetch >> 4) & 0xf) {
//                0,1,3  => dec_rotxr(T, fetch, getwd, ud),
//                8,9,11 => dec_rotr(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            4 => dec_orb(T, fetch, getwd, ud),
//            5 => dec_xorb(T, fetch, getwd, ud),
//            6 => dec_andb(T, fetch, getwd, ud),
//            7 => switch ((fetch >> 4) & 0xf) {
//                0,1,3 => dec_not(T, fetch, getwd, ud),
//                5,7 => dec_extu(T, fetch, getwd, ud),
//                8,9,11 => dec_neg(T, fetch, getwd, ud),
//                13,15 => dec_exts(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            8 => dec_subb(T, fetch, getwd, ud),
//            9 => dec_subw(T, fetch, getwd, ud),
//            0xa => switch ((fetch >> 4) & 0xf) {
//                0 => dec_dec(T, fetch, getwd, ud),
//                8..15 => dec_sub(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            0xb => switch ((fetch >> 4) & 0xf) {
//                0 => dec_subs(T, fetch, getwd, ud),
//                5,7,13,15 => dec_dec(T, fetch, getwd, ud),
//                8,9 => dec_sub(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            0xc,0xd => dec_cmp(T, fetch, getwd, ud),
//            0xe => dec_subx(T, fetch, getwd, ud),
//            0xf => switch ((fetch >> 4) & 0xf) {
//                0 => dec_das(T, fetch, getwd, ud),
//                8..15 => dec_cmp(T, fetch, getwd, ud),
//                else => @panic("illegal insn!"),
//            },
//            else => @panic("wtf"),
//        },
//        2, 3 => dec_movb(T, fetch, getwd, ud),
//        4 => dec_bcc(T, fetch, getwd, ud),
//        5 => switch ((fetch >> 8) & 0xf) {
//            0 => dec_mulxub(T, fetch, getwd, ud),
//            1 => dec_divxub(T, fetch, getwd, ud),
//            2 => dec_mulxuw(T, fetch, getwd, ud),
//            3 => dec_divxuw(T, fetch, getwd, ud),
//            4 => .rts,
//            5,0xc => dec_bsr(T, fetch, getwd, ud),
//            6 => .rte,
//            7 => dec_trapa(T, fetch, getwd, ud),
//            8 => dec_bcc(T, fetch, getwd, ud),
//            0x9,0xa,0xb => dec_jmp(T, fetch, getwd, ud),
//            0xd,0xe,0xf => dec_jsr(T, fetch, getwd, ud),
//            else => @panic("wtf"),
//        },
//        6 => switch ((fetch >> 8) & 0xf) {
//            0 => dec_bset(T, fetch, getwd, ud),
//            1 => dec_bnot(T, fetch, getwd, ud),
//            2 => dec_bclr(T, fetch, getwd, ud),
//            3 => dec_btst(T, fetch, getwd, ud),
//            4 => dec_orw(T, fetch, getwd, ud),
//            5 => dec_xorw(T, fetch, getwd, ud),
//            6 => dec_andw(T, fetch, getwd, ud),
//            7 => dec_bst(T, fetch, getwd, ud),
//            else => dec_mov(T, fetch, getwd, ud),
//        },
//        7 => switch ((fetch >> 8) & 0xf) {
//            0 => dec_bset(T, fetch, getwd, ud),
//            1 => dec_bnot(T, fetch, getwd, ud),
//            2 => dec_bclr(T, fetch, getwd, ud),
//            3 => dec_btst(T, fetch, getwd, ud),
//            4 => dec_bor(T, fetch, getwd, ud),
//            5 => dec_bxor(T, fetch, getwd, ud),
//            6 => dec_band(T, fetch, getwd, ud),
//            7 => dec_bld(T, fetch, getwd, ud),
//            8 => dec_mov(T, fetch, getwd, ud),
//            9,0xa => switch ((fetch >> 8) & 0xf) {
//                0 => dec_mov(T, fetch, getwd, ud),
//                1 => dec_add(T, fetch, getwd, ud),
//                2 => dec_cmp(T, fetch, getwd, ud),
//                3 => dec_sub(T, fetch, getwd, ud),
//                4 => dec_or(T, fetch, getwd, ud),
//                5 => dec_xor(T, fetch, getwd, ud),
//                6 => dec_and(T, fetch, getwd, ud),
//                else => @panic("wtf"),
//            },
//            0xb => dec_eepmov(T, fetch, getwd, ud),
//            0xc,0xe => if ((fetch & 0xf) == 0 || ((fetch >> 8) & 0xf) == 0xe) blk: {
//                const cd = getwd(ud);
//                break :blk switch ((cd >> 8) & 0xff) {
//                    0x63,0x73 => // TODO: btst
//                    0x74 => // TODO: bor/bior
//                    0x75 => // TODO: bxor/bixor
//                    0x76 => // TODO: band/biand
//                    0x77 => // TODO: bld/bild
//                    else => @panic("illegal insn!"),
//                };
//            } else @panic("illegal insn!"),
//            0xd,0xf => if ((fetch & 0xf) == 0 || ((fetch >> 8) & 0xf) == 0xf) blk: {
//                const cd = getwd(ud);
//                break :blk switch ((cd >> 8) & 0xff) {
//                    0x60,0x70 => // TODO: bset
//                    0x61,0x71 => // TODO: bnot
//                    0x62,0x72 => // TODO: bclr
//                    0x67 => // TODO: bst/bist
//                    else => @panic("illegal insn!"),
//                };
//            } else @panic("illegal insn!"),
//            else => @panic("wtf"),
//        },
//        8 => dec_add(T, fetch, getwd, ud),
//        9 => dec_addx(T, fetch, getwd, ud),
//        0xa => dec_cmp(T, fetch, getwd, ud),
//        0xb => dec_subx(T, fetch, getwd, ud),
//        0xc => dec_or(T, fetch, getwd, ud),
//        0xd => dec_xor(T, fetch, getwd, ud),
//        0xe => dec_and(T, fetch, getwd, ud),
//        0xf => dec_mov(T, fetch, getwd, ud),
//        else => @panic("wtf"),
//    };

