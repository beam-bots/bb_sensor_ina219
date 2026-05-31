# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Sensor.INA219 do
  @moduledoc """
  A BB sensor that polls an INA219 voltage / current / power monitor
  over I2C and publishes `BB.Message.Sensor.PowerState` messages.

  The INA219 is a general-purpose power monitor. Use it to watch a battery,
  a motor's draw for stall detection, a logic rail, a solar input, or any
  other electrical bus you can run a shunt resistor on.

  ## Example DSL Usage

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

  ## Options

  - `bus` — I2C bus name (e.g. `"i2c-1"`) — required.
  - `address` — I2C address (default `0x40`).
  - `calibration` — One of `:calibrate_32V_2A` (default), `:calibrate_32V_1A`,
    `:calibrate_16V_400mA`. These match the helper functions on the underlying
    `INA219` library and assume a 0.1Ω shunt resistor (Adafruit breakout).
    Each preset implies a fixed `current_divisor` and `power_divisor`.
  - `publish_rate` — How often to read + publish (default `~u(1 hertz)`).

  ## Published Messages

  `BB.Message.Sensor.PowerState` published to `[:sensor | path]` where `path`
  is the sensor's position in the topology. Fields are in SI units (Volts,
  Amperes, Watts).

  Read failures crash the process — going silent on the topic would hide
  a dead sensor from the supervisor and from downstream consumers. The
  supervisor restarts the process per its restart strategy; if the device
  is genuinely gone (e.g. a USB-attached bus disappeared), `init/1` will
  fail to reacquire and the restart intensity limit propagates the failure
  up the tree.
  """

  use BB.Sensor

  import BB.Unit
  import BB.Unit.Option

  alias BB.Message
  alias BB.Message.Sensor.PowerState
  alias BB.Robot.Units
  alias Localize.Unit
  alias Wafer.Driver.Circuits.I2C, as: CircuitsI2C

  @calibrations [:calibrate_32V_2A, :calibrate_32V_1A, :calibrate_16V_400mA]

  @impl BB.Sensor
  def options_schema do
    Spark.Options.new!(
      bus: [
        type: :string,
        required: true,
        doc: "I2C bus name (e.g. \"i2c-1\")"
      ],
      address: [
        type: :integer,
        default: 0x40,
        doc: "I2C address of the INA219"
      ],
      calibration: [
        type: {:in, @calibrations},
        default: :calibrate_32V_2A,
        doc: "Calibration preset (matches INA219.calibrate_*/1 helpers)"
      ],
      publish_rate: [
        type: unit_type(compatible: :hertz),
        default: ~u(1 hertz),
        doc: "Rate at which to read the sensor and publish PowerState"
      ]
    )
  end

  @impl BB.Sensor
  def init(opts) do
    opts = Map.new(opts)
    {current_divisor, power_divisor} = divisors_for(opts.calibration)

    with {:ok, conn} <-
           CircuitsI2C.acquire(bus_name: opts.bus, address: opts.address),
         {:ok, ina} <-
           INA219.acquire(
             conn: conn,
             current_divisor: current_divisor,
             power_divisor: power_divisor
           ),
         {:ok, ina} <- apply(INA219, opts.calibration, [ina]) do
      publish_interval_ms = hertz_to_ms(opts.publish_rate)

      state = %{
        bb: opts.bb,
        ina: ina,
        publish_interval_ms: publish_interval_ms
      }

      schedule_tick(publish_interval_ms)
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl BB.Sensor
  def handle_info(:tick, state) do
    {:ok, fields} = read(state.ina)
    frame_id = List.last(state.bb.path)
    message = Message.new!(PowerState, frame_id, fields)
    BB.publish(state.bb.robot, [:sensor | state.bb.path], message)
    schedule_tick(state.publish_interval_ms)
    {:noreply, state}
  end

  @impl BB.Sensor
  def handle_options(new_opts, state) do
    new_opts = Map.new(new_opts)
    publish_interval_ms = hertz_to_ms(new_opts.publish_rate)
    {:ok, %{state | publish_interval_ms: publish_interval_ms}}
  end

  defp read(ina) do
    with {:ok, bus_v} <- INA219.bus_voltage(ina),
         {:ok, current_ma} <- INA219.current(ina),
         {:ok, power_mw} <- INA219.power(ina),
         {:ok, shunt_mv} <- INA219.shunt_voltage(ina) do
      {:ok,
       [
         voltage: bus_v,
         current: current_ma / 1000.0,
         power: power_mw / 1000.0,
         shunt_voltage: shunt_mv / 1000.0
       ]}
    end
  end

  defp divisors_for(:calibrate_32V_2A), do: {10, 2}
  defp divisors_for(:calibrate_32V_1A), do: {25, 1}
  defp divisors_for(:calibrate_16V_400mA), do: {20, 1}

  defp hertz_to_ms(rate) do
    rate
    |> Unit.convert!("hertz")
    |> Units.extract_float()
    |> then(&round(1000 / &1))
  end

  defp schedule_tick(ms) do
    Process.send_after(self(), :tick, ms)
  end
end
