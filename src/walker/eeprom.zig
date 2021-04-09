
const std = @import("std");

const Walker = @import("../walker.zig").Walker;

pub const EepState = enum {
    idle,
    rdstat,
    wrstat,
    rdjedec,
    inread,
    inwrite,
    rdmsb,
    rdlsb,
    wrmsb,
    wrlsb,
};

const pagesize = 128;

pub const Eeprom = struct { // ST M95512?
    sys: *Walker,

    state: EepState,
    wren: bool,
    status: u8,
    readptr: u16,
    writeptr: u16,

    data: *[64*1024]u8,

    pub fn init(s: *Walker, data: *[64*1024]u8) Eeprom {
        return Eeprom { .sys = s, .wren = false, .readptr = 0, .writeptr = 0,
            .state = .idle, .data = data, .status = 0
        };
    }
    pub fn load_rom(self: *Eeprom, data: *[64*1024]u8) void {
        self.data = data;
    }

    pub fn reset(self: *Eeprom) void {
        self.state = .idle;
        self.wren = false;
        self.readptr = 0;
        self.writeptr = 0;
        self.status = 0;
    }

    pub fn xfer (self: *Eeprom, v: u8) u8 {
        return switch (self.state) {
            .idle => blk: {
                switch (v) {
                    0x06 => { self.wren = true ; },
                    0x04 => { self.wren = false; },
                    0x05 => { self.state = .rdstat; },
                    0x01 => { self.state = .wrstat; },
                    0x9f => { self.state = .rdjedec; },
                    0x03 => { self.state = .rdmsb; },
                    0x02 => { self.state = .wrmsb; },
                    else => {
                        std.debug.print("E: EEPROM SPI unrecognised cmd 0x{x:}\n", .{v});
                        self.sys.h838606f.sched.ibreak();
                    }
                }
                break :blk 0;
            },
            .rdstat => self.status | (if (self.wren) @as(u8,0) else @as(u8,0xc)),
            .wrstat => blk: {
                self.status = v;
                self.state = .idle;
                break :blk 0;
            },
            .rdjedec => 0xff, // ?
            .rdmsb => blk: {
                self.readptr = (self.readptr & 0x00ff) | (@as(u16,v) << 8);
                self.state = .rdlsb;
                break :blk 0;
            },
            .rdlsb => blk: {
                self.readptr = (self.readptr & 0xff00) | (@as(u16,v) << 0);
                self.state = .inread;
                break :blk 0;
            },
            .wrmsb => blk: {
                self.writeptr = (self.writeptr & 0x00ff) | (@as(u16,v) << 8);
                self.state = .wrlsb;
                break :blk 0;
            },
            .wrlsb => blk: {
                self.writeptr = (self.writeptr & 0xff00) | (@as(u16,v) << 0);
                self.state = .inwrite;
                break :blk 0;
            },
            .inread => blk: {
                std.debug.print("EEP read\n", .{});
                const vv = self.data[self.readptr];
                self.readptr += 1;
                //if (self.readptr % pagesize == 0) //self.state = .idle;
                break :blk vv;
            },
            .inwrite => blk: {
                std.debug.print("EEP read write 0x{x:}\n", .{v});
                if (self.wren) self.data[self.writeptr] = v;
                self.writeptr += 1;
                if (self.writeptr % pagesize == 0) self.writeptr -= pagesize; //self.state = .idle;
                break :blk 0;
            }
        };
    }

    pub fn cs_end(self: *Eeprom) void {
        self.state = .idle;
    }
};

