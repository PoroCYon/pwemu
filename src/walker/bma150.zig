
const std = @import("std");

const Walker = @import("../walker.zig").Walker;

pub const BmaState = enum {
    idle,
    willread,
    inread,
    inwrite,
};

pub const Bma150 = struct { // IO1
    sys: *Walker,

    state: BmaState,

    addr: u7,
    data: [0x80]u8,

    pub fn init(s: *Walker) Bma150 {
        return Bma150 { .sys = s, .addr = undefined, .state = .idle,
            .data=undefined
        };
    }
    pub fn reset(self: *Bma150) void {
        self.addr = undefined;
        self.state = .idle;

        for (self.data) |_, i| self.data[i] = 0;
        self.data[0x00] =  2; // chip ID
        self.data[0x0b] =  3; // enable LG, HG
        self.data[0x0c] = 20; // HG, LG stuff...
        self.data[0x0d] =150;
        self.data[0x0e] =160;
        self.data[0x0f] =150;
        self.data[0x12] =162; // customer 1
        self.data[0x13] = 13; // customer 2
        self.data[0x14] =0b01110; // range, bandwidth
        self.data[0x15] = 0x80; // settings (SPI4 mode)

        self.data[0x2b] =  3; // mirror of 0x0b and onwards
        self.data[0x2c] = 20;
        self.data[0x2d] =150;
        self.data[0x2e] =160;
        self.data[0x2f] =150;
        self.data[0x32] =162;
        self.data[0x33] = 13;
        self.data[0x34] =0b01110;
        self.data[0x35] = 0x80;
    }

    pub fn read(self: *Bma150) u8 {
        return switch (self.state) {
            .idle => blk: {
                std.debug.print("W: read BMA150 SPI in idle state!\n", .{});
                break :blk 0;
            },
            .willread => 0, // dummy stuff
            .inread => blk: {
                const ret = self.data[self.addr];
                self.addr = self.addr +% 1;
                break :blk ret;
            },
            else => blk: {
                std.debug.print("E: read BMA150 SPI in WTF state! {}\n", .{@tagName(self.state)});
                self.sys.h838606f.sched.ibreak();
                break :blk 0;
            }
        };
    }
    pub fn write(self: *Bma150, v: u8) void {
        switch (self.state) {
            .idle => {
                self.addr = @truncate(u7, v);
                if (v & 0x80 == 0) {
                    self.state = .inwrite;
                } else self.state = .willread;
            },
            .willread => self.state = .inread, // strobe write for reads
            .inread => { }, // strobe write for reads
            .inwrite => {
                self.data[self.addr] = v;
                self.addr = self.addr +% 1;
            },
            //else => {
            //    std.debug.print("E: write BMA150 SPI in WTF state! {}\n", .{@tagName(self.state)});
            //    self.sys.h838606f.sched.ibreak();
            //}
        }
    }

    pub fn cs_end(self: *Bma150) void {
        self.state = .idle;
    }
};

