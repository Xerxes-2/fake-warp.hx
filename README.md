# fake-warp.hx

`fake-warp.hx` is a Helix Steel plugin that triggers terminal cursor animations
by briefly flashing an intermediate cursor shape whenever a block cursor is
involved.

Helix's block cursor is rendered as a styled cell rather than the native
terminal cursor, so the terminal's blink/warp animation never resets on its own.
This plugin forces a shape transition to make the terminal redraw its cursor
animation.

It hooks into two events:

- **mode switch** — if either the outgoing or incoming mode uses a block cursor,
  flash an intermediate shape (bar or underline) for a short duration
- **cursor movement** — if the current mode uses a block cursor, briefly flash
  a non-block shape

## Requirements

- Helix built with the Steel event system. See [`STEEL.md`](https://github.com/mattwparas/helix/blob/steel-event-system/STEEL.md).

## Installation

Install the package with Forge:

```sh
forge pkg install --git https://github.com/Xerxes-2/fake-warp.hx.git
```

Then load it from your Helix `init.scm`:

```scheme
(require "fake-warp/fake-warp.scm")
```

The plugin installs itself when required.

## Notes

- Cursor shapes are read automatically from the live editor config on first use —
  no manual configuration needed.
- The intermediate shape is shown for 40 ms by default, which is enough for the
  terminal to render one frame at 60 Hz or above.
- The plugin guards against re-entry so rapid events do not stack animations.
