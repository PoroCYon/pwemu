# pwemu

A very work-in-progress Pokéwalker emulator. Definitely not ready for regular
use for now.

## Dependencies

Only `zig` for now.

## Compiling and running

**Compile:**
```
zig build
```

**Run:**
```
zig build run
```

Or alternatively, run `zig-cache/bin/pwemu` in a debugger after compiling.

## Usage

You need to provide the emulator an EEPROM and flash a ROM image. Right now,
this is done by placing two files in the working directory (the directory you
run `zig build run` in):
- `pweep.rom`: the EEPROM image (65536 bytes)
- `pwflash.rom`: the flash ROM image (49152 bytes)

Once the emulator has started up, the user is greeted with the following
prompt:

```
pc=0x   0 fetched=0x   0 ccr=i------- state=State.reset pending=PendingExn.none
er0=0xaaaaaaaa er1=0xaaaaaaaa er2=0xaaaaaaaa er3=0xaaaaaaaa
er4=0xaaaaaaaa er5=0xaaaaaaaa er6=0xaaaaaaaa er7=0xaaaaaaaa
>
```

The status of the H8/300H CPU is printed, followed by a `> ` prompt. There, you
can enter the number of cycles for which the emulator should run. While
running, it'll print some debug info, until it either reaches a breakpoint in
the emulator (`Sched.ibreak()`, recognisable by the `B!` in the output), or the
system has reached the specified number of cycles.

## Status

CPU and IO ports implemented, SSU and BMA150 have code to get things working,
but need a proper implementation so timings and behavior are actually correct
in all cases, and not just for the code the Pokéwalker happens to run.

Everything else (talking to the EEPROM, LCD display, buzzer, buttons, and much
more) is yet to be started on.

## Internal sturcture

Aka, how to get started working on the source code.

If you don't kno Zig, that's not much of a problem. This is my first Zig
project, too, so I also don't know much about what I'm doing. You'll probably
be fine if you know C and keep [this nice overview of the language
](https://ziglang.org/documentation/0.7.1/) at hand, as that's what I've been
doing.

The entrypoint is in `main.zig`. It instantiatese a `Walker` (from
`walker.zig`), which represents the entire Pokéwalker (NTR-PHC-01 PCB and
components). Most of these components can be found inside the `walker/` folder,
except for the main H8/38606 MCU, which lives in `h838606f.zig`.

The 38606 itself only has a few basic functions: `init()`, `reset()`, to
initialize and reset the system, `run()` to run the MCU for a specified number
of cycles. The `readXX()` and `writeXX()` functions access the system bus, and
are responsible for address decoding, access timings, etc.

The 38606's MMIO peripherals (timers, serial and IrDA input/output, GPIO,
analog inputs, ...) can be found in `h83860x/`, while the H8/300H CPU of the
MCU is in `h8300h.zig`. The CPU uses code in `h8300h/` for instruction decoding
and interpreting, and is mostly finished. The interface the MCU uses to talk to
the peripherals, are their `readXX()` and `writeXX()` functions, which handle
MMIO register accesses, as well as their `reset()` function.

The 38606 can talk to the outside world (i.e. the rest of the PCB), this is
done using an `Iface` struct, containing a few callbacks. The `Walker`
implements these to eg. redirect SPI traffic to the correct component,
depending on the GPIO pin state, which act as chip select.

The final part is the scheduler, in `sched.zig`. It uses `libco` (from Higan)
under the hood, and has more or less the same features as melonDS' scheduler.
The scheduler is used in two different ways: outside the emulated system, you
can instruct it to run the emulated system for a specified number of cycles
(`run()`).  From inside, you can advance the global time by a given number of
cycles (`cycle()`), as well as schedule 'events' a specified number of cycles
into the future. Using `libco`, the scheduler will switch between the emulated
system's thread and the outside world thread as needed.

See [this](https://near.sh/articles/design/cooperative-threading),
[this](https://near.sh/articles/design/cooperative-serialization),
[this](https://near.sh/articles/design/hierarchy) and
[this](https://near.sh/articles/design/schedulers) article for byuu's notes on
how emulator internals work, especially related to the scheduler. Note that,
however, as the Pokéwalker is quite fixed and there's only one main clock,
things can be simplified quite a bit, and therefore, this emulator does not
implement everything talked about in these articles.

[This](https://www.renesas.com/eu/en/products/microcontrollers-microprocessors/other-mcus-mpus/h8-family-mcus/h838602r-super-low-power-16-bit-microcomputers-non-promotion)
page has all the documents talking about the innards of the H8/30606F. You most
likely need the following files:
- "H8/300H manual": describes the CPU, its instructions and instruction
  timings, and so on.
- "H8/38602 group manual": describes the peripherals, their MMIO registers, and
  their functions.
- "H8/38606 update": the document that describes the difference between the
  '602 and the '606 (namely, different ROM and RAM sizes). Other than that, the
  '606 as used in the Pokéwalker is identical to the '602.
