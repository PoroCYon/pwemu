
const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

usingnamespace @import("h838606f.zig");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var gp = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gp.deinit();

    const allocar = &arena.allocator;
    const allocgp = &gp.allocator;

    const d = std.fs.cwd();
    const flash = try d.readFileAlloc(allocar, "./pwflash.rom", 48*1024);
    const eep = try d.readFileAlloc(allocar, "./pweep.rom", 64*1024);

    var h8: H838606F = undefined;
    try H838606F.init(&h8, allocar, allocgp, @ptrCast(*[48*1024]u8, flash));

    h8.reset();
    h8.sched.interactive = true;

    const print = std.debug.print;

    var linelen: usize = 1024;
    var linebuf = @ptrCast([*c]u8, c.calloc(1,linelen));
    defer c.free(linebuf);
    mainloop: while (true) {
        h8.h8300h.stat();
        print("> ", .{});

        const rrr = c.getline(&linebuf, &linelen, c.stdin);
        if (rrr < 0 or c.feof(c.stdin) != 0) {
            //std.debug.print("welp, getline() borked\n", .{});
            break :mainloop;
        }

        if (linelen == 0) {
            // TODO: prev. cmd
        } else {
            // TODO: actual cmd parsing
            const cycles = c.strtoul(linebuf, null, 0);
            print("run for {} cyc\n", .{cycles});
            h8.run(cycles);

            if (h8.sched.broken) {
                print("B! ", .{});
            }
        }
    }
}

// TODO:
// // bset #4, CLKSTPR2 // enable ssu
// b0f6: read8  unknown IO2 address 0xfffb         | CLKSTPR2 (sys)
// b0f8: write8 unknown IO2 address 0xfffb <- 0xba
// // bset #6, SSCRL // enable ssu some more
// b0fe: read8  unknown IO1 address 0xf0e1         | SSCRL (ssu)
// b100: write8 unknown IO1 address 0xf0e1 <- 0xea
// // mov.b #0x86, SSMR // msb first, clk/4
// b106: write8 unknown IO1 address 0xf0e2 <- 0x86 | SSMR
// // mov.b #0x8c, SSCRH // master mode, "misc cfg"
// b10c: write8 unknown IO1 address 0xf0e0 <- 0x8c | SSCRH
// // mov.b #8, PUCR9 // pull up port 3 pin 3
// b112: write8 unknown IO1 address 0xf087 <- 0x8  | PUCR9 (IO port IO1)
// // mov.b #1, PCR9 // port 9 pin 0 is output, rest is input
// b116: write8 unknown IO2 address 0xffec <- 0x1  | PCR9 (IO port IO2)
// // mov.b #7, PCR1 // port 1 pins 0..2 are outputs, rest is input
// b11a: write8 unknown IO2 address 0xffe4 <- 0x7  | PCR1
// // mov.b #5, PDR1 // port 1 pins 0,2 hi, rest lo
// b11e: write8 unknown IO2 address 0xffd4 <- 0x5  | PDR1
// // bset #0, PDR9 // port 9 pin 0 hi
// b120: read8  unknown IO2 address 0xffdc         | PDR9
// b122: write8 unknown IO2 address 0xffdc <- 0xab
// // mov.b #1, PMRB // "PB0 is nIRQ0"
// b124: write8 unknown IO2 address 0xffca <- 0x1  | PMRB
//
// // and.b #4, SSSR // ???
// 2748: read8  unknown IO1 address 0xf0e4         | SSSR (ssu)
// 274e: write8 unknown IO1 address 0xf0e4 <- 0x0
// // mov.b #0x80, PDR9 // TX on
// 2714: write8 unknown IO1 address 0xf0e3 <- 0x80 | SSER
// // bclr #0, PDR9 // port 9 pin 0 low ("likely chip select")
// 2716: read8  unknown IO2 address 0xffdc         | PDR9 (IO)
// 2718: write8 unknown IO2 address 0xffdc <- 0xaa
// // 1: mov.b SSSR, r0l : bld #2, r0l : bcc 1b
// 271c: read8  unknown IO1 address 0xf0e4         | SSSR
// 271c: read8  unknown IO1 address 0xf0e4
// 271c: read8  unknown IO1 address 0xf0e4
// ...
//
// "The system clock is 3.6864MHz, the accelerometer's chip select is port 9
//  pin 0, the EEPROM's chip select is port 1 pin 2, LCD's chip select is
//  port 1 pin 0, and the LCD's D/nC pin is port 1 pin 1. Port B pin 0 is the
//  enter key, B2 is the left key, and B4 is the right key."

