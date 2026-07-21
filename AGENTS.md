<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

`bb_sensor_ina219` is a Beam Bots integration library for the INA219 voltage /
current / power monitor over I2C. A single `BB.Sensor.INA219` sensor module polls
the chip and publishes `BB.Message.Sensor.PowerState` messages.

## Build and Test Commands

```bash
mix check --no-retry    # Run all checks (compile, test, format, credo, dialyzer, reuse)
mix test                # Run tests
mix test path/to/test.exs:42  # Single test at line
mix format
mix credo --strict
```

Prefer `mix check --no-retry` over running individual tools.

## Architecture

A single module, `BB.Sensor.INA219` (`lib/bb/sensor/ina219.ex`), implementing the
`BB.Sensor` behaviour:

- `init/1` opens the I2C bus via `Wafer.Driver.Circuits.I2C.acquire/1`,
  calls `INA219.acquire/1`, applies the configured calibration helper, and
  schedules the first poll tick.
- `handle_info(:tick, state)` reads bus voltage, current, power, and shunt
  voltage from the INA219, builds a `BB.Message.Sensor.PowerState`, publishes
  it on `[:sensor | path]`, and reschedules the next tick.
- `handle_options/2` recomputes the publish interval when `publish_rate` is
  bound to a runtime parameter.

There is intentionally no separate controller process. The INA219 is a
single-stream sensor with one consumer — splitting controller and sensor
into two processes would only add mailbox hops.

## Units

The sensor publishes SI units: Volts, Amperes, Watts. The underlying
`INA219` library returns current in mA and power in mW; conversion happens
in `BB.Sensor.INA219.read/1`.

## Testing

Tests use Mimic to mock `BB`, `INA219`, and `Wafer.Driver.Circuits.I2C`.
Test support modules live in `test/support/`.

## Dependencies

- `bb` — The Beam Bots robotics framework
- `ina219` — Low-level INA219 driver wrapping `Wafer.Conn`
- `wafer` — Hardware abstraction (transitive via `ina219`, declared
  explicitly because we use `Wafer.Driver.Circuits.I2C` directly)
- `circuits_i2c` — I2C backend (declared explicitly; `ina219` lists it as
  optional)

## Licensing headers

Every source file must carry an SPDX header — a `#`-style comment for code, an
HTML comment for Markdown, or a `<file>.license` sidecar for files that can't
hold comments (binaries, JSON, lockfiles). `mix check` runs `reuse lint` and
fails the build if one is missing.

When you create a new file, its `SPDX-FileCopyrightText` line must credit **the
user you are working for** — not you (the agent), and not this repo's original
author. Take their name from `git config user.name` (add their `user.email` if
you include one) and use the current year. Match the neighbouring files'
`SPDX-License-Identifier` (usually `Apache-2.0`):

```
SPDX-FileCopyrightText: <current year> <your user's name>

SPDX-License-Identifier: Apache-2.0
```

Never copy an existing file's copyright line onto a new file — that credits the
wrong person. When you only edit an existing file, leave its headers unchanged.
