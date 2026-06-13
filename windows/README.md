# Gyroball for Windows

A native Windows port of the [Gyroball](../README.md) macOS app for the **NSD
Spinner Powerball** (Bluetooth model PB-700BT). It connects to the ball over BLE
and tracks your workouts from the system tray — no phone needed.

Same idea as the macOS version: the ball is battery-free, so its radio only
powers up while spinning (~3500 RPM to wake, drops off around ~1700 RPM).
Gyroball waits in the tray and reacts the moment you spin.

## What you get

**Floating widget** — a translucent always-on-top overlay that appears when the
ball connects and fades out when you stop:
- Live RPM with a color-coded effort zone (green → blue → yellow → orange → red)
- Hover to expand: live graph, top/average speed, revolutions, session and daily
  totals — or pin it to stay expanded
- Drag it anywhere; the position sticks

**Dashboard** — open from the tray icon (or just launch the app):
- Live view while spinning
- Every session stored in a local SQLite database with speed-over-time charts
- Daily totals, 14-day history, all-time records

Sessions record automatically: spinning starts one, and it saves 45 seconds
after the ball goes quiet. Short bursts within that window count as one session.

## Architecture

The port keeps the macOS app's clean separation:

| Layer | Project | Notes |
|-------|---------|-------|
| Pure logic, storage, session state | `Gyroball.Core` (`net10.0`) | Platform-free; unit-tested on any OS |
| BLE transport, UI, tray, widget | `Gyroball` (`net10.0-windows`) | WPF + WinRT Bluetooth |
| Tests | `Gyroball.Tests` (`net10.0`) | xUnit, covers the Core layer |

- **BLE**: `Windows.Devices.Bluetooth` (WinRT) replaces macOS CoreBluetooth.
- **UI**: WPF replaces SwiftUI/AppKit. The floating widget uses a borderless,
  transparent, top-most window; the tray icon uses
  [H.NotifyIcon](https://github.com/HavenDV/H.NotifyIcon); charts use
  [LiveChartsCore](https://livecharts.dev/).
- **Storage**: `Microsoft.Data.Sqlite`, identical schema to the macOS app.

Data locations:
- Database: `%APPDATA%\Gyroball\gyroball.sqlite`
- Settings (widget position / pin): `%APPDATA%\Gyroball\settings.json`
- Raw packet log: `%LOCALAPPDATA%\Gyroball\Logs\raw.log`

## Requirements

- Windows 10 build 19041 (20H1) or newer / Windows 11
- A Bluetooth LE adapter
- [.NET 10 SDK](https://dotnet.microsoft.com/download) to build

> Bluetooth must be on. On Windows 11, if scanning never connects, check
> **Settings → Privacy & security → Bluetooth devices** and allow desktop apps.

## Build & run

```powershell
# debug build + launch
pwsh ./run.ps1

# run the unit tests
dotnet test

# build a self-contained Gyroball.exe + zip in dist/
pwsh ./release.ps1
```

Or open `Gyroball.slnx` in Visual Studio 2022 (17.13+, which supports the `.slnx`
solution format) and press F5.

> **Note on package versions:** the `.csproj` files pin specific versions of
> H.NotifyIcon.Wpf, LiveChartsCore, CommunityToolkit.Mvvm, and Microsoft.Data.Sqlite.
> If NuGet restore reports a version isn't found, bump it to the latest available —
> the APIs used here are stable across recent releases.

## How it works

Identical protocol to the macOS app: the ball advertises as `NSD Workout`
(service `FFF0`) and streams 8-byte packets on characteristic `FFF4`, where
bytes 2–3 are the rotation period in 4 MHz ticks, so `RPM = 40,000,000 / period`.
The full write-up is in [`../notes/protocol.md`](../notes/protocol.md).

## License

MIT
