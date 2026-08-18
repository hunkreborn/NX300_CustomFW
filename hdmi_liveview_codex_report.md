# Samsung NX300 — HDMI liveview / clean-HDMI static reanalysis

Date: 2026-08-17 (America/Maceio)  
Scope: offline/static analysis only  
Authoritative binary: `live_camera_2026-08-17/di-camera-app-nx300.live`  
SHA-256: `68e3f8a62be1092a55f33b881188503f96a6649210f259b60edb97719e75d6d7`  
Build ID: `3119561d1ec93b05fab09aaed9df83a5936af3b2` (Build311)

Build417 (`di-camera-app-nx300-full`, SHA-256 `ebe6c3680a89d912ccb57ecaeff721283855b9ffa3263c4ecf488571a00b5eeb`) was used only to recover source-level names and enum semantics after instruction-block fingerprinting. Every executable address below is from Build311.

## 1. Executive conclusion

**STRONG EVIDENCE:** the NX300 contains a supported HDMI-liveview transition, separate from the crashing `hdmidemo.adj` CES demonstration. It is entered by the ordinary HDMI playback key handlers when a connected sink advertises a usable 3D mode. The supported transition unit is `UI_Hdmi_3D_Liveview(0)` at `0x150828`; the official callers first destruct the current HDMI playback UI and cancel its low-pass filter.

The gating item is now identified exactly:

- UI value 631 = `eUI_PB_INFO_HDMI_3D_TYPE`, the negotiated/selected sink 3D transport type.
- UI value 946 = `eUI_COMMON_INFO_3D_HDMI_OUTPUT`, the user's 3D HDMI output preference: `0=SIDE_BY_SIDE`, `1=FRAME_PACKING`.

`631` is populated by the XRandR output-selection routine after enumerating modes supplied by the HDMI/XRandR stack (ultimately EDID-derived). It is not merely “HDMI connected” and no evidence makes CEC the gate. With no recognized 3D mode it becomes `OFF(0)`, preventing the official key transition. If compatible modes exist, preference 946 maps to 631=`SIDE_BY_SIDE(1)` or `FRAME_PACKING(3)`.

This path is **not yet clean HDMI in the strict sense**. It sets display control to `VIDEO_ONLY`, which is the strongest clean-output evidence found, but it also deliberately configures the camera's 3D HDMI/liveview mode and sets `UI_Set_HDMI_3D_Type(3)`. A live test should therefore reproduce the official UI event/state transition, not call a hand-picked subset or the CES demo sequence.

## 2. Exact Build311 evidence

### Core functions

| Build311 address | Function / role | Confidence |
|---:|---|---|
| `0x150828` | `UI_Hdmi_3D_Liveview(eUI_HANDLE)` | PROVEN (dynamic symbol) |
| `0x151f28` | `UI_Set_X_Crtc_Config_Liveview(eUI_HANDLE)` | PROVEN |
| `0x15234c` | `UI_Set_X_Crtc_Config()` | PROVEN |
| `0x157c4c` | local `__xrr_output_select(...)` | STRONG EVIDENCE (exact fingerprint + Build417 DWARF) |
| `0x158de0/0x158e18` | only true direct reads of item 946 | PROVEN |
| `0x158e0c` | `UI_Set_Value(631,3)` | PROVEN |
| `0x158e40` | `UI_Set_Value(631,1)` | PROVEN |
| `0x158e50` | `UI_Set_Value(631,0)` | PROVEN |
| `0x1842c8` | `UI_Get_Value(eUI_VALUE_ITEM)` | PROVEN |
| `0x1843e4` | `UI_Set_Value(eUI_VALUE_ITEM,int)` | PROVEN |
| `0x1ede68` | `UI_Set_HDMI_3D_Type(int)` | PROVEN |
| `0x1edf48` | `UI_HDMI_Single_Run_Confirm(int,int)` | PROVEN |

### Exhaustive direct item xrefs

Direct `UI_Get_Value(631)` calls occur at `0xf7308`, `0xf7758`, `0xf7b0c`, `0x1523f8`, `0x158e60`, `0x17702c`, `0x1776a0`, `0x177808`, `0x17a30c`, `0x17a44c`, and `0x1ee104`. Direct item-946 reads occur only at `0x158de4` and `0x158e18`. Direct item-631 writes occur only at `0x158e0c`, `0x158e40`, and `0x158e50`. No direct `UI_Set_Value(946,...)` exists in Build311: it is a persistent menu/database value loaded through the generic value layer.

Relevant strings at Build311 `.rodata` include:

- `0x253620`: `1920x1080`
- `0x25362c`: `1920x1080f`
- `0x2536bc`: `3d`
- `0x2536c0`: `first-----mode flag [0x%x]`
- `0x2536dc`: `3D_FRAME_PACKING-----mode flag [0x%x]`
- `0x253704`: `3D Mode Type [ %d ]`
- `0x2519e0`: `CESDEMO=1`
- `0x2519ec`: `mov-hdmi`
- `0x2519f8`: `CESDEMO=0`

## 3. State-machine reconstruction

### Value 946

Build417 DWARF supplies the exact type and values, corroborated by Build311's menu strings (`MENU_SET_3D_HDMI_OUTPUT`, `MENU_SET_SIDE_BY_SIDE`, `MENU_SET_FRAME_PACKING`) and Build311's comparisons:

```c
enum eUI_3D_HDMI_OUTPUT {
    SIDE_BY_SIDE = 0,
    FRAME_PACKING = 1,
    MAX = 2
};
```

It is a **preference**, not the EDID capability itself. Its backing database field is `eDB_COMMON_MENU_3D_HDMI_OUTPUT` (DB item 250; semantic reference from Build417 DWARF), explaining why no direct setter is present in the application code.

### Value 631

```c
enum eUI_PB_HDMI_3D_TYPE {
    OFF            = 0,
    SIDE_BY_SIDE   = 1,
    TOP_AND_BOTTOM = 2,
    FRAME_PACKING  = 3,
    MAX            = 4
};
```

Build311 never writes value 2 in the mapped state machine.

| 631 | Meaning | How reached in Build311 | Confidence |
|---:|---|---|---|
| 0 | OFF / no recognized usable 3D mode | all four 3D-mode candidate counters/flags are zero, write at `0x158e50` | PROVEN |
| 1 | SIDE_BY_SIDE | at least one 3D candidate and item946==0, write at `0x158e40` | PROVEN |
| 2 | TOP_AND_BOTTOM | enum-defined, but no direct Build311 writer found | PROVEN enum; UNKNOWN reachability |
| 3 | FRAME_PACKING | at least one 3D candidate and item946==1, write at `0x158e0c` | PROVEN |

The underlying local names recovered from the correlated DWARF are `tv_possible_size_3d`, `tv_possible_size_3d_sbs`, `tv_possible_size_3d_sbs_pal`, and `tv_possible_size_3d_pal`. They are set while iterating XRandR mode records and checking calculated refresh, interlace/doublescan flags, and mode-name classes (`1920x1080`, `1920x1080f`, `1280x720[f]`, PAL/NTSC variants, and `3d`). Therefore the predicate is a sink-mode capability predicate rather than a CEC message.

Plausible reconstruction of the final block (`0x158d58..0x158e94`):

```c
if (!tv_possible_size_3d && !tv_possible_size_3d_pal &&
    !tv_possible_size_3d_sbs && !tv_possible_size_3d_sbs_pal) {
    UI_Set_Value(eUI_PB_INFO_HDMI_3D_TYPE, OFF);
} else if (UI_Get_Value(eUI_COMMON_INFO_3D_HDMI_OUTPUT) == FRAME_PACKING) {
    UI_Set_Value(eUI_PB_INFO_HDMI_3D_TYPE, FRAME_PACKING);
} else if (UI_Get_Value(eUI_COMMON_INFO_3D_HDMI_OUTPUT) == SIDE_BY_SIDE) {
    UI_Set_Value(eUI_PB_INFO_HDMI_3D_TYPE, SIDE_BY_SIDE);
} // invalid preference: retain prior value
log("3D Mode Type [ %d ]", UI_Get_Value(631));
```

### Why `UI_Set_X_Crtc_Config()` treats 631==1 specially

At `0x1523f8`, normal HDMI CRTC configuration reads item631. For `SIDE_BY_SIDE(1)`, it selects one of two dedicated stored XRandR mode IDs (`0x318570` or `0x318578`, chosen using item928); other values use `0x31856c`. Those globals are filled by `__xrr_output_select` from distinct 30/50/60 Hz/interlaced mode candidates. This is transport-specific mode selection: SBS needs the SBS-compatible timing selected earlier. It is not a generic “liveview enabled” boolean.

## 4. `UI_Hdmi_3D_Liveview(0/1)` pseudocode

The following preserves call order and important state but gives unknown numeric properties descriptive placeholders.

```c
void UI_Hdmi_3D_Liveview(eUI_HANDLE state) {       // 0 enter, 1 restore
    device_set_property(5, 9, 2);                  // transition/busy; exact enum unknown

    if (state == 0) {
        camera_ioctl_get(cmd_43, &status_struct, &len);
        if (status_struct.byte14 == 0) {            // required camera/lens capability absent
            if (UI_Get_State(201) == 8) UI_Start_Timer(27, ...);
            device_set_property(5, 9, 0);
            return;
        }

        putenv("CESDEMO=1");
        UI_Operate_Display_Ctrl_Set(ALL, DISABLE);  // -1,1
        UI_Operate_Power_Timer(true);
        UI_Set_State(55, 1);                        // HDMI-liveview active flag
        UI_Operate_Key_Mask(0, 0x0fffffff, 0);
        UI_Manage_Playback_Handle(1, false);
        sysmmap_change_opmode("mov-hdmi");
        UI_Set_X_Crtc_Config_Liveview(0);
        if (camera_global_plus_a8 == 0)
            camera_ioctl_set(cmd_66, NULL, 0);
        camera_global_plus_a8 = 0;
        UI_Set_Value(1008, 28);
        UI_Set_HDMI_3D_Type(FRAME_PACKING);         // public enum value 3
        UI_Load_Variable_Current_Mode(28, 0);
        UI_Operate_Liveview_Start();
        UI_Operate_Key_Mask(1, 0x0fffffff, 0);
        UI_Set_State(2, 17);                        // 3D HDMI liveview UI state
        UI_Operate_Lens_MF_Permission(true);
        UI_Operate_Display_Ctrl_Set(ALL, VIDEO_ONLY); // -1,4
        device_set_property(5, 9, 0);
        return;
    }

    if (UI_Get_State(55) != 1) return;
    putenv("CESDEMO=0");
    UI_Operate_Lens_MF_Permission(false);

    if (UI_Get_Value(1010) == 38) {
        UI_Set_State(55, 0);
        UI_Operate_Liveview_Stop();
        UI_Manage_Key_Modechange();
    } else {
        if (device_get_property(5,9) == 1)
            device_set_property(5,9,2);
        UI_Operate_Display_Ctrl_Set(ALL, DISABLE);
        UI_Manage_Key_Modechange();
        if (!global_restore_suppression)
            UI_Set_X_Crtc_Config_Liveview(1);
        device_set_property(5,9,0);
    }
    global_restore_suppression = false;
    UI_Set_State(55,0);
}
```

The exact symbolic names of camera ioctl commands 43/66 and device property `(5,9)` remain UNKNOWN. Their use/order is proven; their labels are intentionally not invented.

### CRTC helper

`UI_Set_X_Crtc_Config_Liveview(0)` at `0x151f28` targets the stored selected 3D mode (`0x31856c`), logical 960×540 and output 1920×1080. When the remembered HDMI dimensions are not already the target, it recreates Device2 at 1920×1080, disables/rebinds CRTC, resizes the X window, updates OSD/window focus, applies the XRandR CRTC and syncs.

`UI_Set_X_Crtc_Config_Liveview(1)` sets item649, calls normal `UI_Set_X_Crtc_Config()`, calls `UI_Set_HDMI_3D_Type(0)`, clears item649, restores playback sizing/touch/folder state, and reconstructs HDMI single-image playback. This confirms `(1)` means leave/restore, not another liveview format.

## 5. Official trigger path

All direct calls to Build311 `0x150828` were classified:

| Caller instruction | Argument | Correlated function | Condition/action |
|---:|---:|---|---|
| `0x1776cc` | 0 | `UI_Key_HDMI_Single_Half_Shutter` | key operation==1 and 631!=0 |
| `0x177834` | 0 | `UI_Key_HDMI_Single_Playback` | key operation==1 and 631!=0 |
| `0x17a334` | 0 | `UI_Key_HDMI_FolderView_Half_Shutter` | 631!=0 |
| `0x17a474` | 0 | `UI_Key_HDMI_FolderView_Playback` | 631!=0 |
| `0x151698` | 1 | `UI_Disconnect_Hdmi` | active flag state55==1 |
| `0x15b164`, `0x15b19c` | 1 | `UI_Event_Key_Manager` | state2==17; exit key events set item1010 first |
| `0x17dc40` | 1 | `UI_Event_Callback_Manager_Lens` | callback ID 5 |
| `0x1e0e50` | 1 | `UI_Start_Modechange_Capture_Mode` | mode-change branch |

Before each ordinary single-playback enter call, the official code executes:

```c
UI_HDMI_Single_Destruct();
ASLPBDisplay_LowPassFilterCancel();
UI_Hdmi_3D_Liveview(0);
```

Folder view uses its corresponding folder destructor before the same transition. The physical actions are therefore **half-press shutter** or the **Playback button**, while already in HDMI single/folder playback on a sink for which item631 is nonzero. This is PROVEN at the function/event level; exact localized on-screen wording is not needed.

`UI_HDMI_Single_Run_Confirm` provides the preceding playback setup: at `0x1ee0fc` it configures the normal CRTC, reads 631 at `0x1ee104`, passes it to `UI_Set_HDMI_3D_Type` at `0x1ee110`, sets item649=1, and draws the HDMI image.

## 6. EDID / sink capability findings

**PROVEN:** the application consumes `_XRROutputInfo` and `_XRRModeInfo` structures in `__xrr_output_select`, reached as part of HDMI output enumeration. It checks mode IDs, dimensions, calculated refresh and XRandR mode flags, compares named timing families, records separate normal/3D/SBS/PAL candidates, and writes the selected mode IDs to globals used by CRTC configuration.

**STRONG EVIDENCE:** those XRandR modes are the server/DRM HDMI connector's EDID-derived modes. The application itself does not parse raw HDMI VSDB bytes in this path; capability is represented by mode name/flags already exposed through XRandR. The literal `3d` and frame-packing flag log occur inside this selector.

**NO EVIDENCE FOUND:** that CEC controls item631 or item946. CEC may exist elsewhere in the stack, but it is not on the mapped item631 writer path.

The effective enable predicate is:

```text
HDMI output enumerated
  -> at least one recognized 3D timing candidate
  -> valid preference 946 (SBS or frame packing)
  -> 631 becomes 1 or 3
  -> HDMI playback half-shutter/Playback handler permits liveview transition
```

## 7. CES `hdmidemo.adj` versus official path

| Aspect | Crashing CES demo | Official playback-to-liveview path |
|---|---|---|
| Entry | hidden `hdmidemo.adj` demonstration | normal HDMI playback key handler |
| Capability guard | bypassed/invented state | requires negotiated item631!=0 |
| UI teardown | ad-hoc | destructs current playback view + cancels low-pass filter |
| Camcorder | explicit stop, attribute rewrite, start | does **not** set `file-format`/`stereo-video-format`; uses UI liveview controller |
| Memory mode | `mov-hdmi` | `mov-hdmi` |
| Environment | CES/demo related | also temporarily sets `CESDEMO=1`; this string alone is not the dangerous distinction |
| CRTC/device | explicit Device2 creation plus manual controls | encapsulated in `UI_Set_X_Crtc_Config_Liveview(0)` |
| 3D type | manually forced | internally forced only after official guards/transition setup |
| Final display | demo sequence | display control `VIDEO_ONLY` through normal UI operation layer |
| Exit/rollback | unclear/crash-prone | `UI_Hdmi_3D_Liveview(1)` restores CRTC/playback and clears state |

### Minimum safe transition sequence

The smallest **supported semantic sequence** identified is not a list of independently callable internals. It is the existing key event in HDMI playback:

1. allow normal HDMI connect/output enumeration to populate 631;
2. verify 631 is nonzero through the UI's own state;
3. while in HDMI single/folder playback, use the native half-shutter or Playback-button event;
4. let that handler perform the matching playback destructor/filter cancellation;
5. let `UI_Hdmi_3D_Liveview(0)` perform its camera capability guard, CRTC, memory mode, liveview, key and display-control sequence;
6. leave through a native exit/disconnect/mode-change event, which invokes `(1)`.

Calling only `Display_Ctrl_Set(VIDEO_ONLY)`, only `UI_Set_X_Crtc_Config_Liveview`, or forcing 631 is not demonstrated safe.

## 8. Remaining unknowns

1. Exact public name/structure field checked by camera ioctl command 43, and exact name of command 66.
2. Exact symbolic name of device property `(5,9)`.
3. Whether a common non-3D monitor ever exposes the special XRandR `3d`/frame-packing modes needed for 631!=0. Likely not.
4. Whether `VIDEO_ONLY` is completely clean at every moment or transient UI/firmware overlays can still appear.
5. Whether forcing an EDID with a valid 3D mode is sufficient, or whether the HDMI driver/camera ioctl guard also requires a 3D-capable lens/capture state.
6. Reachability of enum value 631=2 (`TOP_AND_BOTTOM`) in this firmware.
7. Exact format/frame cadence output by this 3D HDMI liveview path.

## 9. Safest proposed next experiment

**Experiment: native-event observation with a 3D-capable HDMI sink, no injection.**

Objective: validate the supported path without invoking functions or changing application state artificially.

1. Connect a sink known to advertise HDMI 1.4 3D frame-packing/SBS modes.
2. Enter normal HDMI playback using the camera UI.
3. Use only the documented physical half-shutter once; if nothing happens, use the physical Playback key once.
4. Observe whether normal sensor liveview appears and whether overlays are absent.
5. Exit using the same native Playback/disconnect action.
6. Collect only pre-existing application/system logs afterward via the approved read-only wrapper, if needed.

No `hdmidemo.adj`, no runtime function calls, no value writes, no ptrace, no process restart, no mount, and no SD/NAND changes. This experiment depends on obtaining a genuinely 3D-capable sink/EDID; using an EDID emulator would itself be a separate, explicitly authorized external-hardware experiment.

## 10. Rollback

For the proposed native UI experiment: press Playback to leave liveview or physically disconnect HDMI, both of which have mapped calls to `UI_Hdmi_3D_Liveview(1)`. If the UI becomes unresponsive, power-cycle physically only after confirming the filesystem is idle. No persistent camera state is intentionally changed.

## 11. Camera mutations performed

**NONE.**

No camera connection was made during this analysis. No camera/SD/NAND process, mount, file, setting, device, ioctl, or register was modified.

## Reproducibility notes

The analysis used `sha256sum`, `readelf`, `arm-linux-gnueabi-nm`, `arm-linux-gnueabi-objdump`, `strings`, `rg`, and small local text-processing scripts. Direct xrefs were accepted only when the ARM call target resolved to Build311 `UI_Get_Value`, `UI_Set_Value`, or `UI_Hdmi_3D_Liveview`. Build417 names were accepted only where instruction/control-flow fingerprints matched; all reported execution addresses were then re-derived from Build311.

## 12. PR #1 checkpoint — local-variable and evidence ledger

This section records the additional audit performed for the shared PR protocol. It does not change the recommended experiment.

### Correlated local layout of `__xrr_output_select`

The Build417 DWARF frame-base locations are displaced by four bytes from the Build311 `fp` operands (validated using the three formal parameters: DWARF `fbreg -932/-936/-940` corresponds to Build311 `[fp,#-928/-932/-936]`). With that correction, the four final capability tests map as follows:

| Build311 stack slot | Correlated source local | Initialization | Set/use evidence |
|---|---|---:|---|
| `[fp,#-28]` | `tv_possible_size_3d` | `0x157ccc` | set at `0x1581b4`; tested `0x158d58` |
| `[fp,#-32]` | `tv_possible_size_3d_sbs` | `0x157cd4` | set at `0x157fdc`; tested `0x158d70` |
| `[fp,#-36]` | `tv_possible_size_3d_sbs_pal` | `0x157cdc` | set at `0x1580e4`; tested `0x158d7c` |
| `[fp,#-40]` | `tv_possible_size_3d_pal` | `0x157ce4` | set at `0x158208`; tested `0x158d64` |

This makes the final `631=0` condition directly reproducible from Build311 and removes an earlier ambiguity where the four slots could have been mistaken for generic connection flags. The nearby `select_fakemode` local is a different slot (`[fp,#-24]` after the same frame correction) and is not part of the final four-way test.

### Evidence boundary: EDID and CEC

- **PROVEN:** `__xrr_output_select` consumes XRandR output/mode records and the four final booleans are explicitly named 3D timing candidates in correlated DWARF.
- **STRONG INFERENCE:** the X server/HDMI driver populated those records from sink EDID. This is the normal source of connector modes, but raw VSDB parsing is not present in the application routine itself.
- **NOT PROVEN:** that raw EDID bytes, HDMI VSDB, or a specific DRM property directly map to any one local candidate without examining the X server/driver implementation.
- **NO CALL-PATH EVIDENCE:** CEC participates in writes of 631 or reads of 946. This is intentionally narrower than claiming CEC is absent from the firmware.

### Safest remaining static step

Trace the producer of the XRandR mode names/flags (`3d`, `1920x1080f`, and the mode flag tested with bit `0x10`) through the NX300 X server and HDMI DRM/BSP sources. The goal is to identify the exact EDID/VSDB condition that creates the candidate consumed at `0x157c4c`, without altering a sink or camera. In parallel, recover symbolic names for camera ioctl IDs 43 and 66 from the matching capture-framework headers/debug types; neither unknown is a reason to invoke the live process.

## 13. PR #1 checkpoint — VSDB producer, mode-ID ledger and ioctl recovery

This section supersedes the two remaining tasks in section 12. All executable
addresses below are from Build311. Kernel-source paths describe the NX300 BSP
and are not Build417 address substitutions.

### Exact mode-ID globals and candidate classes

The four globals adjacent to the liveview CRTC selector are populated by
`__xrr_output_select` as follows:

| Global | Build311 writer | Candidate | Evidence / later consumer |
|---|---:|---|---|
| `0x31856c` | `0x1581e4` | 1920x1080, 30 Hz, progressive; mandatory HDMI 3D frame-packing timing | read by `UI_Set_X_Crtc_Config_Liveview` at `0x151f78`; read by normal CRTC setup at `0x152450` |
| `0x318570` | `0x15800c` | 1920x1080, 60 Hz, interlaced; mandatory SBS-half timing | selected in the `631==1` branch at `0x1523e0/0x15242c` |
| `0x318578` | `0x158114` | 1920x1080, 50 Hz, interlaced; mandatory SBS-half PAL timing | selected in the `631==1` branch at `0x15243c` |
| `0x318574` | `0x158238` | second 30 Hz progressive/name variant (`tv_possible_size_3d_pal`) | recorded for completeness; no direct use by the visible CRTC helpers was found |

`0x31856c` is zeroed at `0x157750`. If neither 30 Hz candidate exists, it is
overwritten at `0x158c00` with the ordinary selected output mode. Consequently,
the global is a frame-packing mode ID only when the 30 Hz candidate was actually
found; its storage address alone does not prove that semantic.

The mode-name constants used by Build311 include `1920x1080` (`0x253620`) and
`1920x1080f` (`0x25362c`), followed by the analogous 720p/576/480 names. The
candidate classifier checks refresh and XRandR flags as well as those names.

### Proven EDID/VSDB to DRM relationship

The BSP implementation in
`packages/linux-3.5/drivers/gpu/drm/drm_edid.c` parses the HDMI Vendor Specific
Data Block in `cea_hdmi_3d_present()`. When HDMI video and 3D-present bits are
valid, it recognizes frame-packing, top-and-bottom and side-by-side-half
structures. `cea_hdmi_patch_mandatory_3d_modes()` then annotates mandatory
timings:

- 1920x1080 progressive at 30 Hz with `DRM_MODE_FLAG_3D_FRAME_PACKING`;
- 1920x1080 interlaced at 50 Hz with `DRM_MODE_FLAG_3D_SIDE_BY_SIDE_HALF`;
- 1920x1080 interlaced at 60 Hz with `DRM_MODE_FLAG_3D_SIDE_BY_SIDE_HALF`.

The flag definitions are in `include/drm/drm_mode.h`. Critically, the bit
`0x10` tested by the application is `DRM_MODE_FLAG_INTERLACE`, not a 3D flag.
The 3D meaning of the app's 50/60 Hz candidates comes from the kernel's
VSDB-driven mandatory-mode annotation plus the timing class; the app does not
parse raw EDID itself.

The evidence chain is therefore:

`HDMI VSDB -> drm_edid.c 3D parser -> mandatory DRM mode annotation -> X server/XRandR mode record -> __xrr_output_select candidate/global -> item 631`.

The raw EDID-to-kernel portion and the application consumer are **PROVEN** from
source/disassembly. The precise X server conversion of the DRM record into each
NX300-specific `...f` name remains **STRONG EVIDENCE**, not a fully reconstructed
line-by-line call path.

### `UI_Set_HDMI_3D_Type(3)` is deliberate frame-packing selection

Build311 `UI_Set_HDMI_3D_Type(int)` is at `0x1ede68`. Its formal parameter is a
plain `int` (also confirmed by Build417 DWARF), but the complete switch removes
the ambiguity:

```c
void UI_Set_HDMI_3D_Type(int public_type)
{
    switch (public_type) {
    case 0: C3DState::Set3DState(1); break; // OFF layer
    case 1: C3DState::Set3DState(2); break; // SBS layer
    case 2: C3DState::Set3DState(3); break; // top/bottom layer
    case 3: C3DState::Set3DState(4); break; // frame-packing layer
    default: C3DState::Set3DState(1); break;
    }
}
```

At `0x1509a8` the official enter path loads literal `3`; `0x1509ac` calls this
wrapper. Thus this is not an accidental equality between two enum layers: the
wrapper explicitly maps public value 3 to internal state 4.

### Meaning of the `631==SBS` path and the safety mismatch

The official key handler treats 631 only as a nonzero capability gate.
`UI_Hdmi_3D_Liveview(0)` does not consume its exact value. It always:

1. asks `UI_Set_X_Crtc_Config_Liveview(0)` to use `0x31856c`;
2. calls `UI_Set_HDMI_3D_Type(3)`, selecting frame packing.

By contrast, normal HDMI playback setup uses 631==1 to select `0x318570` or
`0x318578`, the 60/50i SBS modes. Therefore item 631 is a playback preference /
capability state, while the special sensor-liveview transport is fixed to
1080p30 frame packing.

This exposes a real edge path: an SBS candidate can make 631 nonzero even when
no 30p candidate was found. In that case `0x31856c` contains the ordinary
fallback mode written at `0x158c00`, yet enter still requests internal
frame-packing state. A fully compliant HDMI 1.4 3D EDID may normally advertise
the mandatory 1080p30 timing, but the application does not enforce that
precondition locally. It is therefore unsafe to use `631!=0` alone as proof
that the transition is coherent.

### Preference 946 validation audit

Build417 semantic correlation proves values 0=SBS, 1=FRAME_PACKING and 2=MAX.
`UI_Set_Attr_3D_Hdmi_Output()` is a no-op in that build, so it supplies no
range check. The persisted preference field is `e_3d_hdmi_output` at offset
`0x47c` in `pref_app.h`; `libprefman.so:pref_app_default` contains zero at that
field, strongly supporting SBS as the factory default. Normal menu tables expose
only 0/1.

No clamp was found for a corrupted/stale value 2. With candidates present, the
writer's value-2 path can leave 631 unchanged rather than resetting it. This is
not reachable through the normal menu/default path, but it remains a genuine
defensive-programming gap. Confidence: **PROVEN control flow**, **STRONG
EVIDENCE normal default**, **HYPOTHESIS for real-world corrupt preference**.

### Camera ioctl IDs 43 and 66

Build417 DWARF contains the `MMCameraUserDataParam` enumerators:

- 43 = `MM_CAMERA_USERDATA_IZOOM`;
- 66 = `MM_CAMERA_USERDATA_3DMOVIEFRAMERATE`.

Build311 uses 43 at `0x150894` through `UI_Get_Camera_Ioctl` and tests a byte at
offset 14 of the returned buffer. The exact field name at that offset remains
unknown. It uses 66 at `0x150978` through `UI_Set_Camera_Ioctl` with null/zero
payload. These symbolic IDs correct the earlier “unknown ioctl” wording; the
implementation behind command 66 still requires capture-framework analysis if
its exact cadence effect is needed.

### Revised safety conclusion

The static state machine is now sufficiently clear to reject any experiment
whose only precondition is `631!=0`. Before a native physical-key test, the sink
must be shown to expose the 1920x1080@30 frame-packing candidate actually stored
in `0x31856c`, not merely a 50/60i SBS candidate. A read-only XRandR/DRM mode
inventory is the safest next evidence step. No direct function invocation,
state write or CES demo path is justified.

### Camera mutations performed for this checkpoint

**NONE.** The investigation was entirely offline/local.
