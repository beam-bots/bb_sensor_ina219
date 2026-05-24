# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.INA219.TestBot do
  @moduledoc """
  Minimal robot for live-testing `BB.INA219` against real hardware.

  Not loaded by default — included in `test/support/` so it's compiled in the
  `:dev` and `:test` envs. Run it from IEx:

      iex> BB.INA219.TestBot.start_link([])
      iex> BB.subscribe(BB.INA219.TestBot, [:sensor, :chassis, :main_bus])
      iex> flush()
  """
  use BB
  import BB.Unit

  settings do
    name(:bb_ina219_test_bot)
  end

  topology do
    link :chassis do
      sensor(
        :main_bus,
        {BB.INA219,
         bus: "ftdi-3:17-i2c",
         address: 0x40,
         calibration: :calibrate_32V_2A,
         publish_rate: ~u(1 hertz)}
      )
    end
  end
end
