
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

usingnamespace @import("h8300h.zig");
usingnamespace @import("h838606f.zig");

const c = @cImport({
    @cInclude("libco.h");
});

pub const Event_ud = *align(8) c_void;
pub const Event = struct {
    id: u64,
    time: u64,
    ud: Event_ud,
    do: fn(*H838606F, Event_ud)void
};

fn cmpTime(ctx: void, a: Event, b: Event) bool {
    return a.time < b.time;
}

threadlocal var mysched: ?*Sched = null; // *libc* threadlocal != libco threadlocal

pub const Sched = struct {
    sys: *H838606F,
    cycles: u64,
    target: u64,
    uidno: u64,
    events: ArrayList(Event),
    runthrd: c.cothread_t,
    mainthrd: c.cothread_t,
    broken: bool,
    interactive: bool,

    pub fn init(s: *H838606F, alloc: *Allocator) Sched {
        return Sched { .sys = s, .cycles = 0, .target = 0, .uidno = 0,
            .events = ArrayList(Event).init(alloc),

            .runthrd = c.co_create(1*1024*1024, runthread),
            .mainthrd = c.co_active(),
            .broken = false, .interactive = true
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

    pub fn enqueue(self: *Sched, t: u64, ev: fn(*H838606F, Event_ud)void, ud: Event_ud) u64 {
        self.uidno = self.uidno + 1;
        const id = self.uidno;
        self.events.append(Event { .time = self.cycles + t, .ud = ud, .do = ev, .id = id }) catch {
            return 0;
        };
        std.sort.sort(Event, self.events.items, {}, cmpTime);
        return id;
    }
    pub fn cancel_ev(self: *Sched, uid: u64) void {
        var ind: usize = undefined;
        var found = false;
        for (self.events.items) |ev, i| {
            if (ev.id == uid) {
                ind = i;
                found = true;
                break;
            }
        }

        if (found) _ = self.events.orderedRemove(ind);
    }

    fn runthread() callconv(.C) void {
        const self = mysched orelse @panic("mysched not set!");
        mysched = null;

        self.sys.h8300h.runthread();
    }

    pub fn run(self: *Sched, inc: u64) void {
        self.target += inc;
        self.broken = false;

        mysched = self;
        while (self.cycles < self.target and !self.broken) {
            c.co_switch(self.runthrd);
        }
        if (self.broken and self.interactive) {
            self.target = self.cycles;
        }
    }

    pub fn ibreak(self: *Sched) void {
        self.broken = true;
        self.cycle_endrun();
    }
};

