import unittest

from nx300_emulator.model import NX300State
from nx300_emulator.shell import EmulatorShell


class EmulatorTests(unittest.TestCase):
    def setUp(self):
        self.state = NX300State()
        self.shell = EmulatorShell(self.state)

    def test_identity(self):
        self.assertEqual(self.shell.run("id"), (0, "uid=0(root) gid=0(root)\n"))

    def test_measured_ct3_registers(self):
        self.assertIn("DATA : a80", self.shell.run("st cap cis regr 0340")[1])
        self.assertIn("DATA : ebc", self.shell.run("st cap cis regr 0342")[1])
        self.assertAlmostEqual(self.state.profile.pixel_clock_hz, 304_000_000, delta=50)

    def test_hdmi_scenario(self):
        self.state.apply_scenario("hdmi-connected")
        self.assertEqual(self.state.cat("/sys/class/drm/card0-HDMI-A-1/status"), "connected\n")
        self.assertEqual(self.state.cat("/sys/class/drm/card0-HDMI-A-1/dpms"), "On\n")

    def test_mutation_is_blocked(self):
        code, output = self.shell.run("dd if=x of=y")
        self.assertEqual(code, 126)
        self.assertIn("blocked", output)


if __name__ == "__main__":
    unittest.main()
