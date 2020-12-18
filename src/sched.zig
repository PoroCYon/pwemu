
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

usingnamespace @import("h8300h.zig");
usingnamespace @import("h838606f.zig");

const c = @cImport({
    @cInclude("libco.h");
});

pub const Event = struct {
    time: u64,
    ud: *c_void,
    do: fn(*H838606F, *c_void)void
};

fn cmpTime(ctx: void, a: Event, b: Event) bool {
    return a.time < b.time;
}

threadlocal var mysched: ?*Sched = null; // *libc* threadlocal != libco threadlocal

pub const Sched = struct {
    sys: *H838606F,
    cycles: u64,
    target: u64,
    events: ArrayList(Event),
    runthrd: c.cothread_t,
    mainthrd: c.cothread_t,

    pub fn init(s: *H838606F, alloc: *Allocator) Sched {
        return Sched { .sys = s, .cycles = 0, .target = 0,
            .events = ArrayList(Event).init(alloc),

            .runthrd = c.co_create(1*1024*1024, runthread),
            .mainthrd = c.co_active()
        };
    }

    pub fn cycle_doEvents(self: *Sched, cyc_: u64) u64 {
        var cyc = cyc_;

        for (self.events.items) |ev| {
            if (ev.time > self.cycles + cyc) {
                break;
            }

            if (ev.time < self.cycles) {
                std.debug.print("aaaaaa event serviced late!\n", .{});
            }

            const diff = ev.time - self.cycles;
            self.cycles = ev.time;
            cyc -= diff;

            ev.do(self.sys, ev.ud);
            //@call(.{}, ev.do, .{self.sys, ev.ud});
        }

        return cyc;
    }
    pub fn cycle_endrun(self: *Sched) void {
        c.co_switch(self.mainthrd); // long-winded way to return through multiple functions at once
    }

    // ONLY CALL FROM THE MAIN DEVICE (H8/300H)
    pub inline fn cycle(self: *Sched, cyc_: u64) void {
        var cyc = cyc_;

        if (self.events.items.len > 0) { // very unlikely
            cyc = self.cycle_doEvents(cyc);
        }

        self.cycles += cyc;

        if (self.cycles >= self.target) { // also kinda unlikely
            self.cycle_endrun();
        }
    }
    pub inline fn cycle_noev(self: *Sched, cyc: u64) void { // can be dangerous!
        self.cycles += cyc;
    }
    pub fn skip(self: *Sched) void {
        if (self.cycles <= self.target) {
            self.cycle(self.target - self.cycles);
        }
    }

    pub fn enqueue(self: *Sched, t: u64, ev: fn(*H838606F, *c_void)void, ud: *c_void) void {
        self.events.enqueue(Event { .time = t, .ud = ud, .do = ev });
        std.sort.sort(Event, self.events.items, {}, cmpTime);
    }

    fn runthread() callconv(.C) void {
        const self = mysched orelse @panic("mysched not set!");
        mysched = null;

        self.sys.h8300h.runthread();
    }

    pub fn run(self: *Sched, inc: u64) void {
        self.target += inc;

        mysched = self;
        while (self.cycles < self.target) {
            c.co_switch(self.runthrd);
        }
    }
};

