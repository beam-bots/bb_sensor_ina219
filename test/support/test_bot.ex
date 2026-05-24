# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Sensor.INA219.TestBot do
  @moduledoc """
  Minimal robot for live-testing `BB.Sensor.INA219` against real hardware.

  Not loaded by default — included in `test/support/` so it's compiled in the
  `:dev` and `:test` envs. Run it from IEx:

      iex> BB.Sensor.INA219.TestBot.start_link([])
      iex> BB.subscribe(BB.Sensor.INA219.TestBot, [:sensor, :chassis, :main_bus])
      iex> flush()
  """
  use BB
  import BB.Unit

  settings do
    name(:bb_sensor_ina219_test_bot)
  end

  topology do
    link :chassis do
      sensor(
        :main_bus,
        {BB.Sensor.INA219,
         bus: "ftdi-3:17-i2c",
         address: 0x40,
         calibration: :calibrate_32V_2A,
         publish_rate: ~u(1 hertz)}
      )
    end
  end
end
