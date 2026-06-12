# Gyroball

A native macOS app for the **NSD Spinner Powerball** (Bluetooth model PB-700BT).
It connects to the ball over BLE and tracks your workouts — no phone needed.

The ball is battery-free: its radio only powers up while spinning (~3500 RPM to
wake, drops off around ~1700 RPM). Gyroball waits in the menu bar and reacts the
moment you spin.

## What you get

**Floating widget** — appears automatically when the ball connects, fades out
when you stop:
- Live RPM with a color-coded effort zone (green → blue → yellow → orange → red)
- Hover to expand: live graph, top/average speed, revolutions, session and
  daily totals — or pin it to stay expanded
- Drag it anywhere; the position sticks

**Dashboard** — open the app from Spotlight or the menu bar icon:
- Live view while spinning
- Every session stored in a local SQLite database (`~/Library/Application
  Support/Gyroball/`) with speed-over-time charts
- Daily totals, 14-day history, all-time records

Sessions record automatically: spinning starts one, and it saves 45 seconds
after the ball goes quiet. Short bursts within that window count as one session.

## Install

Requires macOS 13+ and the Swift toolchain (Xcode Command Line Tools are
enough — no Xcode needed):

```sh
./release.sh   # builds Gyroball.app, installs it to /Applications, and makes a DMG
```

For development:

```sh
./run.sh       # debug build, bundle, sign, launch
```

VS Code users: the included tasks make `Cmd+Shift+B` build and run.

On first launch macOS asks for Bluetooth permission. Then spin the ball past
~3500 RPM and the widget appears.

## How it works

The ball advertises as `NSD Workout` (service `FFF0`) and streams 8-byte
packets on characteristic `FFF4`. Bytes 2–3 are the rotation period in 4 MHz
timer ticks, so `RPM = 40,000,000 / period` — calibrated to within ~1% of the
official NSD Workout app. The full reverse-engineering write-up, including the
GATT layout and the pitfalls, is in [`notes/protocol.md`](notes/protocol.md).

`discovery/scan_and_probe.py` is the Python/bleak probe used to find and
decode the protocol — useful if you want to dig into the still-unknown
characteristics (the ball likely also reports its own revolution counter and
torque on the `FEBA` service).

## License

MIT
