
const std = @import("std");
const print = std.debug.print;

usingnamespace @import("h8300h.zig");

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

pub fn exec(self: *H8300H) void {
    
}

//                     <hi><lo> <hi><lo>
// add.b #xx:8, rd        8<rd> <imm>
// add.b rs, rd           08    <rs><rd>
// add.w #xx:16, rd       79    1<rd>            <imm>    <imm>
// add.w rs, rd           7a    <rs><rd>
// add.l #xx:32, erd      7a    1<0:erd>         <imm>    <imm>    <imm>    <imm>
// add.l ers, erd         0a    <1:ers><0:erd>

// adds #1, erd           0b    0<0:erd>
// adds #2, erd           0b    8<0:erd>
// adds #4, erd           0b    9<0:erd>
//
// addx #xx:8, rd         9<rd> <imm>
// addx rs, rd            0e    <rs><rd>
//
// and.b #xx:8, rd        e<rd> <imm>
// and.b rs, rd           16    <rs><rd>
//

