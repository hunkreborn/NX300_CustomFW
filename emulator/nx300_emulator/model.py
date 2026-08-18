from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class CT3Profile:
    name: str
    fps: float
    frame_length: int
    line_length: int
    mode_register: int
    description: str

    @property
    def pixel_clock_hz(self) -> float:
        return self.fps * self.frame_length * self.line_length


CT3_PROFILES = {
    "liveview30": CT3Profile(
        "liveview30", 29.982830, 0x0A80, 0x0EBC, 0x0005,
        "Measured active NX300 liveview baseline",
    ),
    "factory60": CT3Profile(
        "factory60", 59.965660, 0x0540, 0x0EBC, 0x0005,
        "Timing-model estimate from measured 304 MHz clock; not yet register-verified",
    ),
}


@dataclass
class NX300State:
    hdmi_connected: bool = False
    hdmi_enabled: bool = False
    hdmi_dpms: str = "Off"
    ct3_profile: str = "liveview30"
    boot_seconds: int = 60
    camera_pid: int = 267
    shell_tid: int = 310
    tracer_pid: int = 0
    notes: list[str] = field(default_factory=list)

    def apply_scenario(self, scenario: str) -> None:
        if scenario == "boot":
            return
        if scenario == "hdmi-connected":
            self.hdmi_connected = True
            self.hdmi_enabled = True
            self.hdmi_dpms = "On"
            return
        if scenario == "factory60":
            self.ct3_profile = "factory60"
            return
        raise ValueError(f"unknown scenario: {scenario}")

    @property
    def profile(self) -> CT3Profile:
        return CT3_PROFILES[self.ct3_profile]

    def cat(self, path: str) -> str:
        fixed = {
            "/proc/cpuinfo": (
                "Processor\t: ARMv7 Processor rev 8 (v7l)\n"
                "BogoMIPS\t: 1395.91\n"
                "Features\t: swp half thumb fastmult vfp edsp neon vfpv3 tls\n"
                "CPU implementer\t: 0x41\nCPU architecture: 7\n"
                "CPU variant\t: 0x2\nCPU part\t: 0xc09\nCPU revision\t: 8\n\n"
                "Hardware\t: Samsung-DRIMeIV-NX300\nRevision\t: 0000\n"
                "Serial\t\t: 0000000000000000\n"
            ),
            "/proc/meminfo": (
                "MemTotal:         512092 kB\nMemFree:          65536 kB\n"
                "SwapTotal:             0 kB\nSwapFree:              0 kB\n"
            ),
            "/proc/version": (
                "Linux version 3.5.0+ (youngrae0.cho@tizen5) "
                "(gcc version 4.4.1) #24 PREEMPT Mon Feb 3 14:56:56 KST 2014\n"
            ),
            "/proc/mounts": (
                "ubi0!rootdir / ubifs ro,relatime,bulk_read,no_chk_data_crc 0 0\n"
                "tmpfs /tmp tmpfs rw,relatime 0 0\n"
                "/dev/ubi2_0 /mnt/ubi2 ubifs ro,noatime 0 0\n"
                "/dev/ubi1_0 /mnt/ubi1 ubifs rw,noatime 0 0\n"
                "/dev/mmcblk0p1 /mnt/mmc exfat rw,nosuid,nodev,noatime 0 0\n"
            ),
            "/sys/class/drm/card0-HDMI-A-1/status": "connected\n" if self.hdmi_connected else "disconnected\n",
            "/sys/class/drm/card0-HDMI-A-1/enabled": "enabled\n" if self.hdmi_enabled else "disabled\n",
            "/sys/class/drm/card0-HDMI-A-1/dpms": f"{self.hdmi_dpms}\n",
            "/sys/class/drm/card0-HDMI-A-1/modes": (
                "1920x1080\n1920x1080\n1920x1080\n1920x1080\n"
                "1920x1080\n1920x1080\n1280x720\n1280x720\n720x576\n720x480\n"
            ) if self.hdmi_connected else "",
            f"/proc/{self.camera_pid}/cmdline": "di-camera-app-nx300\0",
        }
        if path == f"/proc/{self.camera_pid}/status":
            return (
                "Name:\tdi-camera-app-n\nState:\tS (sleeping)\n"
                f"Tgid:\t{self.camera_pid}\nPid:\t{self.camera_pid}\nPPid:\t1\n"
                f"TracerPid:\t{self.tracer_pid}\nUid:\t0\t0\t0\t0\n"
                "Gid:\t0\t0\t0\t0\nVmRSS:\t   28508 kB\nThreads:\t71\n"
            )
        if path not in fixed:
            raise FileNotFoundError(path)
        return fixed[path]

    def listdir(self, path: str) -> list[str]:
        directories = {
            "/": ["adj", "bin", "data", "dev", "etc", "home", "lib", "mnt", "opt", "proc", "root", "sbin", "sdcard", "sys", "tmp", "usr", "var"],
            "/sys/class/drm": ["card0", "card0-HDMI-A-1", "card0-LVDS-1", "controlD64", "version"],
            "/sys/class/drm/card0-HDMI-A-1": ["device", "dpms", "edid", "enabled", "modes", "power", "status", "subsystem", "uevent"],
            "/sys/class/video4linux": [],
            "/sys/class/udc": [],
            "/sys/class/net": ["lo", "wlan0"],
            "/usr/bin": ["di-camera-app-nx300", "gst-inspect-0.10", "gst-launch-0.10", "mtp-responder", "smart-wifi-app-nx300", "st", "usb_setting", "wfd-server"],
            "/usr/lib": ["libOMX.SEC.AVC.Encoder.so.0.0.0", "libcapture-fw-slpcam-nx300.so", "libd4c.so.0.19", "libhdmi-cec.so", "libmm-displayer.so", "libmmfcamcorder.so.0.0.0", "libmmutil_movie.so.0.0.0", "libsecmfcencapi.so.0.0.0"],
            "/mnt/mmc": ["DCIM", "MISC", "SYSTEM"],
        }
        key = path.rstrip("/") or "/"
        if key not in directories:
            raise FileNotFoundError(path)
        return directories[key]
