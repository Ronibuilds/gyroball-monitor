# NSD Powerball BLE Protocol Notes

Reverse-engineered from an NSD Spinner Powerball Automatic Bluetooth
(model PB-700BT, FCC ID 2AK45-NSD-700BT), verified against the official
NSD Workout app.

## Device identity
- Device name: `NSD Workout`
- Radio chip: AMICCOM Electronics (MAC OUI `18:7A:93`)
- Advertised service UUID: `FFF0`
- The ball is battery-free: the rotor magnets power the electronics, so the
  radio only runs while spinning fast enough.

## Wake / sleep behaviour
- BLE activates at roughly **3500 RPM** and keeps advertising while spinning.
- The radio dies when the rotor drops below roughly **1700 RPM** — the
  connection drops; the ball re-advertises automatically on the next spin-up.

## GATT layout
| Service | Characteristic | Properties | Purpose |
|---------|----------------|------------|---------|
| `FFF0`  | `FFF4`         | Read, Notify | **Telemetry** (decoded below) |
| `FFF0`  | `FFF1`, `FFF3` | Write      | Commands (not yet decoded) |
| `FEBA`  | `FA10`, `FA13` | Notify     | Unknown (logged to `~/Library/Logs/Gyroball/raw.log`) |
| `FEBA`  | `FA11`         | Indicate   | Unknown |

No pairing or auth is required — subscribe to `FFF4` and packets flow.

## FFF4 telemetry packet (8 bytes)

```
00 00 | PP PP | 00 00 | FF CC
```

| Offset | Length | Endian | Field | Notes |
|--------|--------|--------|-------|-------|
| 0      | 2      | —      | always `0000` | padding / unused |
| 2      | 2      | BE     | **rotation period** | timer ticks between rotor pulses |
| 4      | 2      | —      | always `0000` | padding / unused |
| 6      | 1      | —      | flag  | `01` seen at high speed, `00` otherwise |
| 7      | 1      | —      | counter | increments per packet |

### Speed decode

The period value is **inversely** proportional to speed (it rises as the
ball slows). The timer reference is 4 MHz:

```
RPM = 40_000_000 / period
```

Calibration against the NSD Workout app (two simultaneous readings):

| raw period | NSD app RPM | formula gives | error |
|-----------|-------------|---------------|-------|
| 23441     | 1694        | 1706          | +0.7% |
| 10213     | 3920        | 3917          | −0.1% |

Pitfall for future reverse-engineers: a short packet capture can't tell you
the sign of the relationship (decelerating with newest-first logs looks
identical to accelerating with oldest-first logs). Verify live with the
ball in hand.

## Open questions
- [ ] What do the `FEBA` characteristics carry? (suspect: cumulative
      revolution counter and/or torque — the NSD app shows "Max Torque")
- [ ] What commands do `FFF1`/`FFF3` accept?
- [ ] What exactly do bytes 6–7 of the FFF4 packet encode?
