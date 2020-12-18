
const std = @import("std");

const c = @cImport({
    @cInclude("libco.h");
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
    h8.run(10);
}

