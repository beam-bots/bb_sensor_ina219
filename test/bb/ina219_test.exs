# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.INA219Test do
  use ExUnit.Case, async: true
  use Mimic

  import BB.Unit

  alias BB.Message
  alias BB.Message.Sensor.PowerState

  @sensor_name :ina219_test
  @sensor_path [:chassis, @sensor_name]

  defp default_bb_context do
    %{robot: TestRobot, path: @sensor_path, name: @sensor_name}
  end

  defp default_opts(overrides \\ []) do
    [
      bb: default_bb_context(),
      bus: "i2c-1",
      address: 0x40,
      calibration: :calibrate_32V_2A,
      publish_rate: ~u(1 hertz)
    ]
    |> Keyword.merge(overrides)
  end

  defp fake_conn, do: :fake_wafer_conn

  defp fake_ina do
    %INA219{conn: fake_conn(), current_divisor: 10, power_divisor: 2}
  end

  defp stub_acquire_success do
    stub(Wafer.Driver.Circuits.I2C, :acquire, fn _opts -> {:ok, fake_conn()} end)
    stub(INA219, :acquire, fn _opts -> {:ok, fake_ina()} end)
    stub(INA219, :calibrate_32V_2A, fn ina -> {:ok, ina} end)
    stub(INA219, :calibrate_32V_1A, fn ina -> {:ok, ina} end)
    stub(INA219, :calibrate_16V_400mA, fn ina -> {:ok, ina} end)
  end

  defp stub_read_success do
    stub(INA219, :bus_voltage, fn _ina -> {:ok, 12.4} end)
    stub(INA219, :current, fn _ina -> {:ok, 850.0} end)
    stub(INA219, :power, fn _ina -> {:ok, 10_540.0} end)
    stub(INA219, :shunt_voltage, fn _ina -> {:ok, 8.5} end)
  end

  defp drain_self_tick do
    receive do
      :tick -> :ok
    after
      50 -> :no_tick
    end
  end

  describe "init/1" do
    test "succeeds and returns state with the resolved ina struct and interval" do
      stub_acquire_success()

      assert {:ok, state} = BB.INA219.init(default_opts())
      assert state.ina == fake_ina()
      assert state.publish_interval_ms == 1000
      assert state.bb == default_bb_context()
      drain_self_tick()
    end

    test "passes bus_name and address through to Wafer" do
      test_pid = self()

      expect(Wafer.Driver.Circuits.I2C, :acquire, fn opts ->
        send(test_pid, {:wafer_opts, opts})
        {:ok, fake_conn()}
      end)

      stub(INA219, :acquire, fn _ -> {:ok, fake_ina()} end)
      stub(INA219, :calibrate_32V_2A, fn ina -> {:ok, ina} end)

      BB.INA219.init(default_opts(bus: "i2c-3", address: 0x41))

      assert_receive {:wafer_opts, opts}
      assert opts[:bus_name] == "i2c-3"
      assert opts[:address] == 0x41
      drain_self_tick()
    end

    test "derives divisors from :calibrate_32V_2A" do
      stub(Wafer.Driver.Circuits.I2C, :acquire, fn _ -> {:ok, fake_conn()} end)
      stub(INA219, :calibrate_32V_2A, fn ina -> {:ok, ina} end)
      test_pid = self()

      expect(INA219, :acquire, fn opts ->
        send(test_pid, {:acquire_opts, opts})
        {:ok, fake_ina()}
      end)

      BB.INA219.init(default_opts(calibration: :calibrate_32V_2A))

      assert_receive {:acquire_opts, opts}
      assert opts[:current_divisor] == 10
      assert opts[:power_divisor] == 2
      drain_self_tick()
    end

    test "derives divisors from :calibrate_32V_1A" do
      stub(Wafer.Driver.Circuits.I2C, :acquire, fn _ -> {:ok, fake_conn()} end)
      stub(INA219, :calibrate_32V_1A, fn ina -> {:ok, ina} end)
      test_pid = self()

      expect(INA219, :acquire, fn opts ->
        send(test_pid, {:acquire_opts, opts})
        {:ok, fake_ina()}
      end)

      BB.INA219.init(default_opts(calibration: :calibrate_32V_1A))

      assert_receive {:acquire_opts, opts}
      assert opts[:current_divisor] == 25
      assert opts[:power_divisor] == 1
      drain_self_tick()
    end

    test "derives divisors from :calibrate_16V_400mA" do
      stub(Wafer.Driver.Circuits.I2C, :acquire, fn _ -> {:ok, fake_conn()} end)
      stub(INA219, :calibrate_16V_400mA, fn ina -> {:ok, ina} end)
      test_pid = self()

      expect(INA219, :acquire, fn opts ->
        send(test_pid, {:acquire_opts, opts})
        {:ok, fake_ina()}
      end)

      BB.INA219.init(default_opts(calibration: :calibrate_16V_400mA))

      assert_receive {:acquire_opts, opts}
      assert opts[:current_divisor] == 20
      assert opts[:power_divisor] == 1
      drain_self_tick()
    end

    test "applies the configured calibration helper" do
      stub(Wafer.Driver.Circuits.I2C, :acquire, fn _ -> {:ok, fake_conn()} end)
      stub(INA219, :acquire, fn _ -> {:ok, fake_ina()} end)
      test_pid = self()

      expect(INA219, :calibrate_32V_1A, fn ina ->
        send(test_pid, :calibrate_called)
        {:ok, ina}
      end)

      BB.INA219.init(default_opts(calibration: :calibrate_32V_1A))

      assert_receive :calibrate_called
      drain_self_tick()
    end

    test "translates publish_rate to interval in milliseconds" do
      stub_acquire_success()

      assert {:ok, %{publish_interval_ms: 100}} =
               BB.INA219.init(default_opts(publish_rate: ~u(10 hertz)))

      drain_self_tick()

      assert {:ok, %{publish_interval_ms: 2}} =
               BB.INA219.init(default_opts(publish_rate: ~u(500 hertz)))

      drain_self_tick()
    end

    test "schedules a tick" do
      stub_acquire_success()

      {:ok, _} = BB.INA219.init(default_opts(publish_rate: ~u(1000 hertz)))

      assert_receive :tick, 50
    end

    test "stops on Wafer acquire failure" do
      expect(Wafer.Driver.Circuits.I2C, :acquire, fn _ -> {:error, :no_such_bus} end)

      assert {:stop, :no_such_bus} = BB.INA219.init(default_opts())
    end

    test "stops on INA219.acquire failure" do
      stub(Wafer.Driver.Circuits.I2C, :acquire, fn _ -> {:ok, fake_conn()} end)
      expect(INA219, :acquire, fn _ -> {:error, :bad_divisor} end)

      assert {:stop, :bad_divisor} = BB.INA219.init(default_opts())
    end

    test "stops on calibration failure" do
      stub(Wafer.Driver.Circuits.I2C, :acquire, fn _ -> {:ok, fake_conn()} end)
      stub(INA219, :acquire, fn _ -> {:ok, fake_ina()} end)
      expect(INA219, :calibrate_32V_2A, fn _ -> {:error, :calibration_failed} end)

      assert {:stop, :calibration_failed} = BB.INA219.init(default_opts())
    end
  end

  describe "handle_info(:tick, state)" do
    setup do
      state = %{
        bb: default_bb_context(),
        ina: fake_ina(),
        publish_interval_ms: 1000
      }

      {:ok, state: state}
    end

    test "reads all four values and publishes PowerState in SI units", %{state: state} do
      stub_read_success()
      test_pid = self()

      expect(BB, :publish, fn robot, path, %Message{payload: %PowerState{} = payload} ->
        send(test_pid, {:published, robot, path, payload})
        :ok
      end)

      assert {:noreply, ^state} = BB.INA219.handle_info(:tick, state)

      assert_receive {:published, TestRobot, [:sensor, :chassis, @sensor_name], payload}
      assert payload.voltage == 12.4
      assert_in_delta payload.current, 0.85, 1.0e-6
      assert_in_delta payload.power, 10.54, 1.0e-6
      assert_in_delta payload.shunt_voltage, 0.0085, 1.0e-6
      drain_self_tick()
    end

    test "frame_id is the sensor name", %{state: state} do
      stub_read_success()
      test_pid = self()

      expect(BB, :publish, fn _robot, _path, %Message{} = msg ->
        send(test_pid, {:frame_id, msg.frame_id})
        :ok
      end)

      BB.INA219.handle_info(:tick, state)

      assert_receive {:frame_id, @sensor_name}
      drain_self_tick()
    end

    test "skips publishing on read error and stays alive", %{state: state} do
      stub(INA219, :bus_voltage, fn _ -> {:error, :i2c_timeout} end)
      reject(&BB.publish/3)

      assert {:noreply, ^state} = BB.INA219.handle_info(:tick, state)
      drain_self_tick()
    end

    test "reschedules a tick at publish_interval_ms", %{state: state} do
      stub_read_success()
      stub(BB, :publish, fn _, _, _ -> :ok end)

      state = %{state | publish_interval_ms: 10}
      BB.INA219.handle_info(:tick, state)

      assert_receive :tick, 50
    end

    test "reschedules even after a read error", %{state: state} do
      stub(INA219, :bus_voltage, fn _ -> {:error, :i2c_timeout} end)

      state = %{state | publish_interval_ms: 10}
      BB.INA219.handle_info(:tick, state)

      assert_receive :tick, 50
    end
  end

  describe "handle_options/2" do
    test "recomputes publish_interval_ms" do
      state = %{
        bb: default_bb_context(),
        ina: fake_ina(),
        publish_interval_ms: 1000
      }

      assert {:ok, new_state} =
               BB.INA219.handle_options([publish_rate: ~u(50 hertz)], state)

      assert new_state.publish_interval_ms == 20
      assert new_state.ina == state.ina
    end
  end
end
