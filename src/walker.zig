
const std = @import("std");
const Allocator = std.mem.Allocator;

usingnamespace @import("iface.zig");

const H838606F = @import("h838606f.zig").H838606F;

pub const Walker = struct {
    h838606f: H838606F,

//  [0FFD4h].0  Port 1 Data bit0 OUT  SPI LCD writeselect (0=select)
//  [0FFD4h].1  Port 1 Data bit1 OUT  SPI LCD access mode (0=Cmd, 1=Dta?)
//  [0FFD4h].2  Port 1 Data bit2 OUT  SPI EEPROM chipselect (0=select)
//  [0FFD6h].0  Port 3 Data bit0      ?
//  [0FFD6h].2  Port 3 Data bit2      ?
//  [0FFDBh].2  Port 8 Data bit2      ?
//  [0FFDBh].3  Port 8 Data bit3      ?
//  [0FFDBh].4  Port 8 Data bit4 OUT  A/D related ... whatfor LCD? accel? batt?
//  [0FFDCh].0  Port 9 Data bit0 OUT  SPI Accelerometer chipselect (0=select)
//  [0FFDEh].0  Port B Data bit0 IN   ?  ;\
//  [0FFDEh].2  Port B Data bit2 IN   ?  ; maybe buttons
//  [0FFDEh].4  Port B Data bit4 IN   ?  ;/
//  [0FFDEh].5  Port B Data bit5 OUT  ?

    lcd_cs: bool,
    lcd_access: u1,
    eep_cs: bool,
    acc_cs: bool,

    // TODO: BMA150, SSD1854, EEPROM, speaker, buttons

    pub fn read_io(self_: Iface_ud, port: u8) u8 {
        const self = @ptrCast(*Walker, self_);

        std.debug.print("IO read port {x:}\n", .{port});

        return 0;
    }
    pub fn write_io(self_: Iface_ud, port: u8, val: u8, mask: u8) void {
        const self = @ptrCast(*Walker, self_);

        std.debug.print("IO write port {x:} <- 0x{x:} & 0x{x:}\n", .{port,val,mask});

        switch (port) {
            1 => {
                if (mask & (1<<0) != 0) {
                    self.lcd_cs = (val & (1<<0)) == 0;
                    std.debug.print("lcd_cs = {}\n", .{self.lcd_cs});
                    //self.h838606f.h8300h.stat();
                }
                if (mask & (1<<1) != 0) {
                    self.lcd_access = @truncate(u1,val>>1);
                    std.debug.print("lcd_access = {}\n", .{self.lcd_access});
                    //self.h838606f.h8300h.stat();
                }
                if (mask & (1<<2) != 0) {
                    self.eep_cs = (val & (1<<2)) == 0;
                    std.debug.print("eep_cs = {}\n", .{self.eep_cs});
                    //self.h838606f.h8300h.stat();
                }
            },
            9 => {
                if (mask & (1<<0) != 0) {
                    self.acc_cs = (val & (1<<0)) == 0;
                    std.debug.print("acc_cs = {}\n", .{self.acc_cs});
                    //self.h838606f.h8300h.stat();
                }
            },
            else => { }
        }
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

        try H838606F.init(&ret.h838606f, iface, @ptrCast(Iface_ud, ret),
            alloc, allocgp, flashrom);

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

