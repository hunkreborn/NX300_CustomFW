# NX300 Codex / ChatGPT Coordination

This repository is a reverse-engineering workspace for the Samsung NX300.

## Authoritative project context

Before starting or continuing work, read:

- PROJECT_CONTEXT.MD
- findings.md
- hdmi_liveview_codex_report.md

The exact live-camera Build311 binary is kept locally and is intentionally not
tracked by Git.

## Shared PR protocol

The branch `codex/hdmi-liveview` and its pull request are the coordination
channel between Codex and ChatGPT.

When doing an investigation:

1. Work autonomously on local static analysis.
2. Do not stop merely to ask the user to run objdump/grep/readelf commands.
3. Commit useful reports, scripts, notes, and reproducible analysis artifacts.
4. Push meaningful checkpoints to `codex/hdmi-liveview`.
5. Use the shared PR conversation for:
   - important discoveries;
   - hypotheses needing independent review;
   - uncertainty about state machines or semantics;
   - proposed live-camera experiments;
   - questions for ChatGPT.
6. Before proceeding after a review checkpoint, read the latest PR discussion.

## Camera safety boundary

Static/offline analysis is unrestricted within the local workspace.

Do NOT autonomously perform camera mutations.

Without explicit user approval, do not:

- write NAND/MTD/UBI;
- access /dev/mem;
- invoke internal HDMI/UI/camcorder functions in the live process;
- use ptrace against the camera application;
- bind-mount application replacements;
- kill/restart the camera application;
- reboot the camera;
- create hdmidemo.adj;
- modify SD-card boot scripts.

If live information is genuinely necessary, use only the existing read-only
camera access wrapper and keep the operation observational.

## Evidence discipline

Build311 is authoritative.

Build417/DWARF may be used for semantic/signature reference only. Never copy
Build417 addresses into Build311 conclusions without independent validation.

Distinguish clearly between:

- proven fact;
- strong inference;
- hypothesis;
- unresolved unknown.

For important conclusions, preserve addresses, call paths, strings, and other
reproducible evidence.

## Current focus

Determine the safest official HDMI-liveview / clean-HDMI path without relying
on the crashing CES `hdmidemo.adj` path.

Primary unresolved targets include:

- UI value 946;
- UI value 631 and its state machine;
- official callers of UI_Hdmi_3D_Liveview(0);
- HDMI/EDID/3D sink capability detection;
- minimum safe official transition from normal liveview to HDMI output.

