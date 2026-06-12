#!/usr/bin/env python3
"""
NSD Powerball BLE reverse-engineering probe.

Usage:
  python scan_and_probe.py                  # scan, print all devices
  python scan_and_probe.py --filter NSD     # filter by name substring
  python scan_and_probe.py --address AA:BB:CC:DD:EE:FF  # connect directly

Requires: pip install bleak
macOS: grant Terminal Bluetooth permission in System Settings → Privacy.
"""

import asyncio
import argparse
import sys
import time
from datetime import datetime
from bleak import BleakScanner, BleakClient
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData


# ---------------------------------------------------------------------------
# Scan phase
# ---------------------------------------------------------------------------

async def scan(filter_name: str | None, duration: float = 10.0) -> list[tuple[BLEDevice, AdvertisementData]]:
    """Scan for BLE devices, optionally filtering by name substring."""
    print(f"\n[*] Scanning for {duration}s …")
    devices: list[tuple[BLEDevice, AdvertisementData]] = []

    def callback(device: BLEDevice, adv: AdvertisementData):
        name = device.name or ""
        if filter_name and filter_name.lower() not in name.lower():
            return
        devices.append((device, adv))
        mfr_hex = ""
        if adv.manufacturer_data:
            for company_id, data in adv.manufacturer_data.items():
                mfr_hex = f"  mfr[0x{company_id:04X}]={data.hex()}"
        svc_uuids = " ".join(str(u) for u in adv.service_uuids) if adv.service_uuids else "—"
        svc_data = ""
        if adv.service_data:
            for uuid, data in adv.service_data.items():
                svc_data = f"  svc_data[{uuid}]={data.hex()}"
        print(
            f"  {'[' + name + ']':30s}  addr={device.address}  RSSI={adv.rssi:4d} dBm"
            f"  svcs={svc_uuids}{mfr_hex}{svc_data}"
        )

    async with BleakScanner(callback):
        await asyncio.sleep(duration)

    # De-duplicate by address (callback fires on every advertisement)
    seen: dict[str, tuple[BLEDevice, AdvertisementData]] = {}
    for d, a in devices:
        seen[d.address] = (d, a)
    return list(seen.values())


def print_adv_analysis(adv: AdvertisementData):
    """Summarise what the advertisement tells us before connecting."""
    print("\n[*] Advertisement analysis:")
    if adv.manufacturer_data:
        for cid, data in adv.manufacturer_data.items():
            print(f"    Manufacturer data  company=0x{cid:04X}  len={len(data)}  hex={data.hex()}")
            print(f"      → bytes: {' '.join(f'{b:02X}' for b in data)}")
    if adv.service_data:
        for uuid, data in adv.service_data.items():
            print(f"    Service data  uuid={uuid}  len={len(data)}  hex={data.hex()}")
    if not adv.manufacturer_data and not adv.service_data:
        print("    No in-advertisement payload (telemetry likely via GATT notifications).")
    if adv.service_uuids:
        print(f"    Advertised service UUIDs: {', '.join(str(u) for u in adv.service_uuids)}")
    else:
        print("    No service UUIDs advertised.")


# ---------------------------------------------------------------------------
# GATT enumeration
# ---------------------------------------------------------------------------

async def enumerate_gatt(client: BleakClient):
    """Print every service + characteristic with UUID, handle, properties."""
    print("\n[*] GATT services and characteristics:")
    for service in client.services:
        print(f"\n  SERVICE  {service.uuid}  ({service.description or 'unknown'})")
        for char in service.characteristics:
            props = ", ".join(char.properties)
            print(f"    CHAR  {char.uuid}  handle=0x{char.handle:04X}  [{props}]")
            if "read" in char.properties:
                try:
                    val = bytes(await client.read_gatt_char(char.uuid))
                    print(f"           read → {val.hex()}  ({_try_decode(val)})")
                except Exception as e:
                    print(f"           read → ERROR: {e}")
            for desc in char.descriptors:
                try:
                    dval = bytes(await client.read_gatt_descriptor(desc.handle))
                    print(f"      DESC  {desc.uuid}  handle=0x{desc.handle:04X}  → {dval.hex()}")
                except Exception as e:
                    print(f"      DESC  {desc.uuid}  handle=0x{desc.handle:04X}  → ERROR: {e}")


def _try_decode(data: bytes) -> str:
    """Best-effort human-readable hint for a raw byte blob."""
    hints = []
    if len(data) >= 2:
        hints.append(f"uint16_le={int.from_bytes(data[:2], 'little')}")
        hints.append(f"uint16_be={int.from_bytes(data[:2], 'big')}")
    if len(data) >= 4:
        hints.append(f"uint32_le={int.from_bytes(data[:4], 'little')}")
    try:
        hints.append(f"str={data.decode('utf-8')!r}")
    except Exception:
        pass
    return "  ".join(hints)


# ---------------------------------------------------------------------------
# Live notification listener
# ---------------------------------------------------------------------------

# Per-characteristic state for change detection
_last_values: dict[str, bytes] = {}
_packet_counts: dict[str, int] = {}

def make_notification_handler(char_uuid: str):
    def handler(_, data: bytearray):
        raw = bytes(data)
        now = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        _packet_counts[char_uuid] = _packet_counts.get(char_uuid, 0) + 1
        count = _packet_counts[char_uuid]

        changed = _last_values.get(char_uuid) != raw
        _last_values[char_uuid] = raw

        marker = "▶" if changed else " "  # highlight when bytes actually changed
        # Annotate with interpretations to help spot RPM / rev bytes
        interp = _interpret(raw)
        print(
            f"{marker} {now}  [{char_uuid[-8:]}] #{count:5d}  "
            f"len={len(raw):2d}  {raw.hex()}  {interp}"
        )
    return handler


def _interpret(data: bytes) -> str:
    """Produce candidate interpretations of every sub-slice to spot patterns."""
    if not data:
        return ""
    parts = []
    # Common sizes for RPM fields (0–50000 rpm typically fits in 2 bytes)
    for i in range(len(data) - 1):
        le = int.from_bytes(data[i:i+2], "little")
        be = int.from_bytes(data[i:i+2], "big")
        if 100 <= le <= 20000:
            parts.append(f"[{i}:{i+2}]LE={le}")
        if 100 <= be <= 20000 and be != le:
            parts.append(f"[{i}:{i+2}]BE={be}")
    # 4-byte candidates (cumulative revolutions could be large)
    for i in range(len(data) - 3):
        le4 = int.from_bytes(data[i:i+4], "little")
        if 1 <= le4 <= 10_000_000:
            parts.append(f"[{i}:{i+4}]LE32={le4}")
    return "  ".join(parts) if parts else ""


async def listen_notifications(client: BleakClient, duration: float):
    """Subscribe to every notifiable characteristic and print packets."""
    notifiable = [
        char
        for service in client.services
        for char in service.characteristics
        if "notify" in char.properties or "indicate" in char.properties
    ]

    if not notifiable:
        print("\n[!] No notifiable characteristics found — device may push data only via advertising.")
        return

    print(f"\n[*] Subscribing to {len(notifiable)} notifiable characteristic(s) …")
    for char in notifiable:
        await client.start_notify(char.uuid, make_notification_handler(char.uuid))
        print(f"    ✓ subscribed to {char.uuid}")

    print(f"\n[*] Listening for {duration}s — spin the ball now!\n")
    print(f"    {'▶ = changed bytes since last packet':40s}  columns: timestamp  [uuid-tail] #seq  len  hex  interpretations\n")

    await asyncio.sleep(duration)

    print("\n[*] Stopping subscriptions …")
    for char in notifiable:
        try:
            await client.stop_notify(char.uuid)
        except Exception:
            pass

    print("\n[*] Packet summary:")
    for uuid, count in _packet_counts.items():
        print(f"    {uuid}: {count} packets")


# ---------------------------------------------------------------------------
# Disconnect / sleep detection
# ---------------------------------------------------------------------------

_disconnect_time: float | None = None

def on_disconnect(client: BleakClient):
    global _disconnect_time
    _disconnect_time = time.time()
    print(f"\n[!] Device disconnected at {datetime.now().strftime('%H:%M:%S')} — may have gone to sleep.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main():
    parser = argparse.ArgumentParser(description="NSD Powerball BLE probe")
    parser.add_argument("--filter", "-f", metavar="NAME", help="Filter scan by name substring")
    parser.add_argument("--address", "-a", metavar="ADDR", help="Skip scan, connect directly to this address")
    parser.add_argument("--scan-time", type=float, default=10.0, help="Scan duration in seconds (default: 10)")
    parser.add_argument("--listen-time", type=float, default=60.0, help="Notification listen duration in seconds (default: 60)")
    args = parser.parse_args()

    target_device: BLEDevice | None = None
    target_adv: AdvertisementData | None = None

    if args.address:
        print(f"[*] Using provided address: {args.address}")
    else:
        results = await scan(args.filter, duration=args.scan_time)

        if not results:
            print("\n[!] No devices found. Tips:")
            print("    - Make sure Bluetooth is on and Terminal has Bluetooth permission.")
            print("    - Try spinning the ball so it wakes up.")
            print("    - Use --filter with a substring of the device name.")
            sys.exit(1)

        print(f"\n[*] Found {len(results)} unique device(s).")

        if len(results) == 1:
            target_device, target_adv = results[0]
            print(f"[*] Auto-selecting: {target_device.name or '(unnamed)'}  {target_device.address}")
        else:
            print("\nSelect a device to connect to:")
            for i, (d, _) in enumerate(results):
                print(f"  [{i}] {d.name or '(unnamed)':30s}  {d.address}")
            idx = int(input("Enter index: ").strip())
            target_device, target_adv = results[idx]

    # Show advertisement analysis before connecting
    if target_adv:
        print_adv_analysis(target_adv)

    addr = args.address or target_device.address
    name = (target_device.name if target_device else None) or addr
    print(f"\n[*] Connecting to {name} ({addr}) …")

    async with BleakClient(addr, disconnected_callback=on_disconnect) as client:
        print(f"[*] Connected. MTU={client.mtu_size}")

        await enumerate_gatt(client)
        await listen_notifications(client, duration=args.listen_time)

        if _disconnect_time is not None:
            idle = time.time() - _disconnect_time
            print(f"[*] Device went offline {idle:.1f}s ago — suggests it sleeps after motion stops.")

    print("\n[*] Done.")


if __name__ == "__main__":
    asyncio.run(main())
