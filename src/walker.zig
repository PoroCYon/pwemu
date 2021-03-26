
const std = @import("std");
const Allocator = std.mem.Allocator;

usingnamespace @import("iface.zig");

const H838606F = @import("h838606f.zig").H838606F;

pub const Walker = struct {
    h838606f: H838606F,

    // TODO: BMA150, SSD1854, EEPROM, speaker, buttons

    pub fn read_io(self_: Iface_ud, port: u8) u8 {
        const self = @ptrCast(*Walker, self_);

        return 0;
    }
    pub fn write_io(self_: Iface_ud, port: u8, val: u8) void {
        const self = @ptrCast(*Walker, self_);

    }
    pub fn serial_read(self_: Iface_ud) u8 {
        const self = @ptrCast(*Walker, self_);

        return 0;
    }
    pub fn serial_write(self_: Iface_ud, val: u8) void {
        const self = @ptrCast(*Walker, self_);

    }

    pub fn init(ret: *Walker, alloc: *Allocator, allocgp: *Allocator,
            flashrom: *[48*1024]u8, eeprom: *[64*1024]u8) !void {
        const iface = Iface { .read_io = read_io, .write_io = write_io,
            .serial_read = serial_read, .serial_write = serial_write };

        try H838606F.init(&ret.h838606f, iface, alloc, allocgp, flashrom);

        // TODO: init BMA150, SSD1854, EEPROM, speaker, buttons
    }

    pub inline fn load_flashrom(self: *Walker, flashrom: *[48*1024]u8) void {
        self.h838606f.load_rom(flashrom);
    }
    pub fn load_eeprom(self: *Walker, eeprom: *[64*1024]u8) void {
        // TODO
    }

    pub fn reset(self: *Walker) void {
        self.h838606f.reset();

        // TODO: reset BMA150, SSD1854, EEPROM, speaker, buttons
    }

    pub inline fn run(self: *Walker, inc: u64) void {
        self.h838606f.run(inc);
    }
};

