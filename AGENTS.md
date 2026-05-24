<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

`bb_ina219` is a Beam Bots integration library for the INA219 voltage /
current / power monitor over I2C. A single `BB.INA219` sensor module polls
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

A single module, `BB.INA219` (`lib/bb/ina219.ex`), implementing the
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
in `BB.INA219.read/1`.

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
