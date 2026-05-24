# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.BbIna219.Install do
    @shortdoc "Installs BB.INA219 into a robot"
    @moduledoc """
    #{@shortdoc}

    Adds a `:config.:ina219` param group with `bus` and `address`, sets the
    bus name on the robot's child spec in your application module, and
    imports `bb_ina219` into your formatter.

    The sensor itself lives on a specific link — the installer can't guess
    which one, so it prints a snippet for you to paste into the topology.

    ## Example

    ```bash
    mix igniter.install bb_ina219
    mix igniter.install bb_ina219 --bus ftdi-3:17-i2c
    ```

    ## Options

    * `--robot` - The robot module (defaults to `{AppPrefix}.Robot`).
    * `--bus` - The I2C bus name (default `i2c-1`).
    """

    use Igniter.Mix.Task

    alias Igniter.Project.Formatter

    @param_group :ina219
    @default_bus "i2c-1"

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        schema: [
          robot: :string,
          bus: :string
        ],
        aliases: [r: :robot]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      options = igniter.args.options
      robot_module = BB.Igniter.robot_module(igniter)
      bus = Keyword.get(options, :bus, @default_bus)

      igniter
      |> Formatter.import_dep(:bb_ina219)
      |> BB.Igniter.add_param_group(robot_module, [:config, @param_group], param_group_body())
      |> BB.Igniter.set_robot_opts(robot_module,
        params: [config: [{@param_group, [bus: bus]}]]
      )
      |> Igniter.add_notice(topology_snippet())
    end

    defp param_group_body do
      """
      param :bus, type: :string, doc: "I2C bus name (e.g. \\"i2c-1\\")"

      param :address,
        type: :integer,
        default: 0x40,
        doc: "I2C address of the INA219"
      """
    end

    defp topology_snippet do
      """
      bb_ina219: add a sensor to whichever link you want to monitor. Example:

          link :chassis do
            sensor :main_bus, {BB.INA219,
              bus: param([:config, :ina219, :bus]),
              address: param([:config, :ina219, :address]),
              calibration: :calibrate_32V_2A,
              publish_rate: ~u(1 hertz)
            }
          end

      Calibration presets: :calibrate_32V_2A, :calibrate_32V_1A,
      :calibrate_16V_400mA. All assume a 0.1Ω shunt (Adafruit breakout).
      """
    end
  end
else
  defmodule Mix.Tasks.BbIna219.Install do
    @shortdoc "Installs BB.INA219 into a robot"
    @moduledoc false
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The bb_ina219.install task requires igniter.

          mix igniter.install bb_ina219
      """)

      exit({:shutdown, 1})
    end
  end
end
