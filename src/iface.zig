
// serves as interface between the H8/3060x and the outside world

pub const Iface_ud = *align(16) c_void;

pub const Iface = struct {
    // H8/3060x reads from an IO port
    read_io : fn (self: Iface_ud, port: u8) u8,
    // H8/3060x writes to an IO port
    write_io: fn (self: Iface_ud, port: u8, val: u8) void,

    // H8/3060x reads a byte from the serial thingy
    serial_read : fn (self: Iface_ud) u8,
    // H8/3060x writes a byte to the serial thingy
    serial_write: fn (self: Iface_ud, val: u8) void,

    // TODO: prototypes for timer W/buzzer
    // TODO: interrupt stuff!
};

