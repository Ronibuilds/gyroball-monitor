# NSD Powerball BLE Protocol Notes

Fill this in as you run scan_and_probe.py.

## Device identity
- Device name:
- BLE address:
- Advertised service UUIDs:

## Advertisement payload
- Manufacturer data: (yes/no, raw hex)
- Service data: (yes/no)
- Conclusion: advertising telemetry passively? (yes/no)

## GATT services & characteristics
<!-- Paste relevant output from the probe here -->

## Notifiable characteristics
| UUID | Packet rate | Packet length | Notes |
|------|-------------|---------------|-------|
|      |             |               |       |

## Byte map (fill in after spinning)
| Offset | Length | Endian | Field     | Scaling | Notes |
|--------|--------|--------|-----------|---------|-------|
|        |        |        | RPM       |         |       |
|        |        |        | Total rev |         |       |
|        |        |        | Top speed |         |       |
|        |        |        | Torque    |         |       |
|        |        |        | Duration  |         |       |

## Sleep / wake behaviour
- Device disconnects after N seconds of no motion:
- Re-advertises automatically on motion: yes/no

## Open questions
- [ ] Is there a write characteristic for commands (start session, reset stats)?
- [ ] Does subscribing require auth / pairing?
