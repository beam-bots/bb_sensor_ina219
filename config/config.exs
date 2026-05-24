# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

import Config

# In this library's own dev/test environments we talk to a real INA219 over
# an FT232H on the laptop. Downstream consumers configure their own
# Circuits.I2C backend (e.g. the kernel driver on a Nerves target).
config :circuits_i2c, default_backend: CircuitsFT232H.I2C.Backend
