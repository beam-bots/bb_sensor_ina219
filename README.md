<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# bb_sensor_ina219

[Beam Bots](https://github.com/beam-bots/bb) integration for the
[INA219](https://www.ti.com/product/INA219) voltage / current / power monitor
over I2C.

Polls the chip at a configurable rate and publishes
`BB.Message.Sensor.PowerState` messages with bus voltage (V), current (A),
power (W), and shunt voltage (V).

## Usage

```elixir
defmodule MyRobot do
  use BB

  topology do
    link :chassis do
      sensor :main_bus, {BB.Sensor.INA219,
        bus: "i2c-1",
        address: 0x40,
        calibration: :calibrate_32V_2A,
        publish_rate: ~u(10 hertz)
      }
    end
  end
end
```

Subscribe to readings:

```elixir
BB.subscribe(MyRobot, [:sensor, :chassis, :main_bus])
```

See `BB.Sensor.INA219` for full options.

## Options

| Option         | Default              | Description                                       |
| -------------- | -------------------- | ------------------------------------------------- |
| `bus`          | _required_           | I2C bus name (e.g. `"i2c-1"`)                     |
| `address`      | `0x40`               | I2C address                                       |
| `calibration`  | `:calibrate_32V_2A`  | One of three INA219 presets (see below)           |
| `publish_rate` | `~u(1 hertz)`        | Polling / publish rate                            |

Calibration presets (all assume a 0.1Ω shunt — Adafruit breakout):

- `:calibrate_32V_2A` — 32V bus range, ±2A current range
- `:calibrate_32V_1A` — 32V bus range, ±1A current range
- `:calibrate_16V_400mA` — 16V bus range, ±400mA current range
