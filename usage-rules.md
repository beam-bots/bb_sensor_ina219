<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# BB.Sensor.INA219 Usage Rules

`bb_sensor_ina219` provides `BB.Sensor.INA219`, a `BB.Sensor` driver for the
INA219 voltage / current / power monitor over I²C (via `wafer`) for
[Beam Bots](https://hexdocs.pm/bb). It polls the chip and publishes
`BB.Message.Sensor.PowerState`. For BB framework basics, see `bb`'s rules
(`mix usage_rules.sync <file> bb:all`); this file covers only what's specific to
this sensor.

## Core principles

1. **It's a declared component, not something you start yourself.** Wire it into
   a `sensor` slot; BB validates its options, injects context, and supervises
   the process. You never call `start_link` or write a `child_spec`.
2. **It publishes raw electrical state, not battery state.** `PowerState` is an
   instantaneous snapshot (voltage, current, power, shunt voltage). Charge
   percentage, state-of-health, and time-remaining are a *downstream*
   consumer's job (`BB.Message.Sensor.BatteryState`) — don't expect them here.
3. **Calibration must match your hardware.** The presets assume a 0.1Ω shunt
   (Adafruit breakout) and each fixes the current/power divisors. The wrong
   preset gives silently wrong current and power readings.

## Wiring it in

Attach it to whichever link or joint carries the bus you're monitoring (or a
robot-level `sensors` block). The value is `{BB.Sensor.INA219, opts}`:

```elixir
topology do
  link :chassis do
    sensor :main_bus, {BB.Sensor.INA219,
      bus: "i2c-1",
      address: 0x40,
      calibration: :calibrate_32V_2A,
      publish_rate: ~u(1 hertz)
    }
  end
end
```

`mix igniter.install bb_sensor_ina219` adds a `[:config, :ina219]` param group
and prints a topology snippet; `bus`/`address` can then be `param([...])`
references resolved at runtime.

## The published message

`BB.Message.Sensor.PowerState` is published on `[:sensor | path]` — the sensor's
position in the topology. Fields are SI units (Volts, Amperes, Watts); the
driver converts the underlying library's mA/mW itself. Subscribe by path:

```elixir
BB.subscribe(MyRobot.Robot, [:sensor, :chassis, :main_bus])

def handle_info({:bb, _path, %BB.Message{payload: %BB.Message.Sensor.PowerState{
      voltage: v, current: a, power: w}}}, state) do
  {:noreply, state}
end
```

## Options

| Option | Default | Meaning |
|---|---|---|
| `:bus` | _required_ | I²C bus name, e.g. `"i2c-1"` |
| `:address` | `0x40` | I²C address |
| `:calibration` | `:calibrate_32V_2A` | Preset: also `:calibrate_32V_1A`, `:calibrate_16V_400mA` |
| `:publish_rate` | `~u(1 hertz)` | Read + publish rate (`~u` sigil, hertz-compatible) |

## Anti-patterns

- **Don't guess the calibration preset.** Match it to your bus voltage and
  expected current range (and a 0.1Ω shunt); otherwise readings are wrong, not
  merely imprecise.
- **Don't set `simulation: :omit` expectations here.** Unlike controllers,
  a `sensor` has no simulation switch — the INA219 attempts to open its real
  I²C bus even under `simulation: :kinematic`, and `init/1` stops the process if
  the device is absent. Omit it from the topology (or mock the bus) when running
  without hardware.
- **Don't rely on it going quiet on failure.** A read error crashes the process
  by design so the supervisor sees a dead sensor; treat the absence of messages,
  not a "zero" reading, as the failure signal.

## Further reading

- [bb_sensor_ina219 docs](https://hexdocs.pm/bb_sensor_ina219)
- `bb`'s PubSub/sensor rules (`bb:pubsub-and-sensors`) and
  [Sensors and PubSub](https://hexdocs.pm/bb/03-sensors-and-pubsub.html)
