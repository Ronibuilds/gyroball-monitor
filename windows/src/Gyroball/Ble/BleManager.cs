using System.IO;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;
using Gyroball.Core;

namespace Gyroball.Ble;

/// <summary>
/// Windows BLE transport for the NSD Powerball. The macOS app used CoreBluetooth;
/// this is the WinRT (Windows.Devices.Bluetooth) equivalent. It scans for the
/// "NSD Workout" advertisement, connects, subscribes to the FFF4 telemetry
/// characteristic, and feeds raw packets into the platform-free <see cref="LiveTelemetry"/>.
///
/// The ball is battery-free: its radio drops below ~1700 RPM and re-advertises on
/// the next spin-up, so the watcher stays armed and we reconnect automatically.
///
/// IMPORTANT — WinRT vs CoreBluetooth advertisement model: CoreBluetooth merges the
/// ADV_IND and SCAN_RSP packets into one peripheral with a unified name. WinRT raises
/// a separate Received event per packet, and the name and the service UUID usually
/// arrive in DIFFERENT packets. So we must NOT require both in one packet — we scan
/// unfiltered and match if the packet carries FFF0 OR is named "NSD Workout", then
/// connect by the (stable) Bluetooth address.
/// </summary>
public sealed class BleManager : IDisposable
{
    private static readonly Guid ServiceUuid   = BluetoothUuidHelper.FromShortId(0xFFF0);
    private static readonly Guid TelemetryUuid = BluetoothUuidHelper.FromShortId(0xFFF4);
    private static readonly Guid ExtraService  = BluetoothUuidHelper.FromShortId(0xFEBA);
    private const string DeviceName = "NSD Workout";

    private readonly LiveTelemetry _live;
    private readonly Action<Action> _post;   // marshal onto the UI thread

    private BluetoothLEAdvertisementWatcher? _watcher;
    private BluetoothLEDevice? _device;
    private readonly List<GattDeviceService> _services = new();
    private readonly List<GattCharacteristic> _subscribed = new();
    private bool _connecting;
    private int _packetCount;

    public BleManager(LiveTelemetry live, Action<Action> post)
    {
        _live = live;
        _post = post;
    }

    public async void Start()
    {
        BleLog.Append("=== Gyroball BLE start ===");
        await LogAdapterAsync();

        _watcher = new BluetoothLEAdvertisementWatcher
        {
            ScanningMode = BluetoothLEScanningMode.Active   // active = also pull scan responses (where the name lives)
        };
        // NOTE: deliberately NO advertisement filter — see class remarks. We match in code.
        _watcher.Received += OnAdvertisementReceived;
        _watcher.Stopped += (_, e) => BleLog.Append($"watcher stopped: {e.Error}");
        _watcher.Start();
        BleLog.Append($"watcher started (status={_watcher.Status})");
    }

    private static async Task LogAdapterAsync()
    {
        try
        {
            var adapter = await BluetoothAdapter.GetDefaultAsync();
            if (adapter is null) { BleLog.Append("WARNING: no Bluetooth adapter found"); return; }
            BleLog.Append($"adapter: LE supported={adapter.IsLowEnergySupported}, " +
                          $"central role={adapter.IsCentralRoleSupported}");
        }
        catch (Exception ex) { BleLog.Append($"adapter query failed: {ex.Message}"); }
    }

    private void RestartScan()
    {
        try
        {
            if (_watcher is { Status: BluetoothLEAdvertisementWatcherStatus.Stopped })
            {
                _watcher.Start();
                BleLog.Append("watcher restarted");
            }
        }
        catch (Exception ex) { BleLog.Append($"restart scan failed: {ex.Message}"); }
    }

    private static bool Matches(BluetoothLEAdvertisementReceivedEventArgs args) =>
        args.Advertisement.LocalName == DeviceName ||
        args.Advertisement.ServiceUuids.Contains(ServiceUuid);

    private async void OnAdvertisementReceived(
        BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args)
    {
        if (_connecting || _device is not null) return;
        if (!Matches(args)) return;

        _connecting = true;
        var addr = FormatAddress(args.BluetoothAddress);
        var uuids = string.Join(",", args.Advertisement.ServiceUuids);
        BleLog.Append($"MATCH addr={addr} name='{args.Advertisement.LocalName}' rssi={args.RawSignalStrengthInDBm} uuids=[{uuids}]");
        sender.Stop();

        try
        {
            var device = await BluetoothLEDevice.FromBluetoothAddressAsync(args.BluetoothAddress);
            if (device is null)
            {
                BleLog.Append("FromBluetoothAddressAsync returned null — cannot open device");
                _connecting = false;
                RestartScan();
                return;
            }

            _device = device;
            device.ConnectionStatusChanged += OnConnectionStatusChanged;
            BleLog.Append($"opened device '{device.Name}' status={device.ConnectionStatus}");

            await DiscoverAsync(device);

            if (_subscribed.Count > 0)
            {
                _post(() => _live.SetConnected(true));
                BleLog.Append($"connected — {_subscribed.Count} notification(s) active");
            }
            else
            {
                BleLog.Append("ERROR: no characteristics subscribed — connection not usable; retrying scan");
                Cleanup();
                RestartScan();
            }
        }
        catch (Exception ex)
        {
            BleLog.Append($"connect failed: {ex.GetType().Name}: {ex.Message}");
            Cleanup();
            RestartScan();
        }
        finally
        {
            _connecting = false;
        }
    }

    private async Task DiscoverAsync(BluetoothLEDevice device)
    {
        // FFF0/FFF4 is the telemetry stream. FEBA carries still-undecoded data;
        // subscribe to everything notifiable there and log it for future analysis.
        await SubscribeAsync(device, ServiceUuid, TelemetryUuid);
        await SubscribeAllNotifiable(device, ExtraService);
    }

    private async Task SubscribeAsync(BluetoothLEDevice device, Guid service, Guid characteristic)
    {
        var svc = await device.GetGattServicesForUuidAsync(service, BluetoothCacheMode.Uncached);
        BleLog.Append($"service {Short(service)}: status={svc.Status} count={svc.Services.Count}");
        if (svc.Status != GattCommunicationStatus.Success) return;

        foreach (var s in svc.Services)
        {
            _services.Add(s);
            var chars = await s.GetCharacteristicsForUuidAsync(characteristic, BluetoothCacheMode.Uncached);
            BleLog.Append($"  char {Short(characteristic)}: status={chars.Status} count={chars.Characteristics.Count}");
            if (chars.Status != GattCommunicationStatus.Success) continue;
            foreach (var c in chars.Characteristics)
                await EnableNotify(c);
        }
    }

    private async Task SubscribeAllNotifiable(BluetoothLEDevice device, Guid service)
    {
        var svc = await device.GetGattServicesForUuidAsync(service, BluetoothCacheMode.Uncached);
        BleLog.Append($"service {Short(service)}: status={svc.Status} count={svc.Services.Count}");
        if (svc.Status != GattCommunicationStatus.Success) return;

        foreach (var s in svc.Services)
        {
            _services.Add(s);
            var chars = await s.GetCharacteristicsAsync(BluetoothCacheMode.Uncached);
            if (chars.Status != GattCommunicationStatus.Success) continue;
            foreach (var c in chars.Characteristics)
            {
                var props = c.CharacteristicProperties;
                if (props.HasFlag(GattCharacteristicProperties.Notify) ||
                    props.HasFlag(GattCharacteristicProperties.Indicate))
                {
                    await EnableNotify(c);
                }
            }
        }
    }

    private async Task EnableNotify(GattCharacteristic c)
    {
        var value = c.CharacteristicProperties.HasFlag(GattCharacteristicProperties.Notify)
            ? GattClientCharacteristicConfigurationDescriptorValue.Notify
            : GattClientCharacteristicConfigurationDescriptorValue.Indicate;

        try
        {
            var status = await c.WriteClientCharacteristicConfigurationDescriptorAsync(value);
            BleLog.Append($"    notify {Short(c.Uuid)}: {status}");
            if (status != GattCommunicationStatus.Success) return;

            c.ValueChanged += OnCharacteristicValueChanged;
            _subscribed.Add(c);
        }
        catch (Exception ex)
        {
            BleLog.Append($"    notify {Short(c.Uuid)} failed: {ex.Message}");
        }
    }

    private void OnCharacteristicValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args)
    {
        var data = ReadBytes(args.CharacteristicValue);
        RawLog.Append(sender.Uuid, data);

        if (sender.Uuid != TelemetryUuid) return;

        if (++_packetCount <= 3)
            BleLog.Append($"telemetry packet #{_packetCount}: {Convert.ToHexString(data)}");

        var now = DateTime.Now;
        _post(() => _live.HandlePacket(data, now));
    }

    private void OnConnectionStatusChanged(BluetoothLEDevice sender, object args)
    {
        BleLog.Append($"connection status → {sender.ConnectionStatus}");
        if (sender.ConnectionStatus == BluetoothConnectionStatus.Disconnected)
        {
            _post(() => _live.SetConnected(false));
            Cleanup();
            RestartScan();
        }
    }

    private static byte[] ReadBytes(IBuffer buffer)
    {
        var reader = DataReader.FromBuffer(buffer);
        var bytes = new byte[buffer.Length];
        reader.ReadBytes(bytes);
        return bytes;
    }

    private void Cleanup()
    {
        foreach (var c in _subscribed)
            c.ValueChanged -= OnCharacteristicValueChanged;
        _subscribed.Clear();

        foreach (var s in _services) s.Dispose();
        _services.Clear();

        if (_device is not null)
        {
            _device.ConnectionStatusChanged -= OnConnectionStatusChanged;
            _device.Dispose();
            _device = null;
        }
        _packetCount = 0;
    }

    private static string Short(Guid g) => g.ToString().Substring(4, 4).ToUpperInvariant();

    private static string FormatAddress(ulong addr) =>
        string.Join(":", BitConverter.GetBytes(addr).Take(6).Reverse().Select(b => b.ToString("X2")));

    public void Dispose()
    {
        if (_watcher is not null)
        {
            _watcher.Received -= OnAdvertisementReceived;
            try { _watcher.Stop(); } catch { /* already stopped */ }
            _watcher = null;
        }
        Cleanup();
    }
}

/// <summary>Appends raw GATT packets to %LOCALAPPDATA%\Gyroball\Logs\raw.log for protocol work.</summary>
internal static class RawLog
{
    private static readonly object Gate = new();
    private static readonly string Path = LogPaths.File("raw.log");

    public static void Append(Guid uuid, byte[] data)
    {
        try
        {
            var hex = data.Length == 0 ? "" : string.Join(' ',
                Enumerable.Range(0, data.Length).Select(i => data[i].ToString("X2")));
            var line = $"{DateTime.Now:HH:mm:ss.fff} {uuid} {hex}{Environment.NewLine}";
            lock (Gate) File.AppendAllText(Path, line);
        }
        catch { /* logging is best-effort */ }
    }
}

/// <summary>Human-readable connection diagnostics at %LOCALAPPDATA%\Gyroball\Logs\ble.log.</summary>
internal static class BleLog
{
    private static readonly object Gate = new();
    private static readonly string Path = LogPaths.File("ble.log");

    public static void Append(string message)
    {
        try
        {
            var line = $"{DateTime.Now:HH:mm:ss.fff} {message}{Environment.NewLine}";
            lock (Gate) File.AppendAllText(Path, line);
        }
        catch { /* best-effort */ }
    }
}

internal static class LogPaths
{
    public static string File(string name)
    {
        var dir = System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Gyroball", "Logs");
        Directory.CreateDirectory(dir);
        return System.IO.Path.Combine(dir, name);
    }
}
