using System.Diagnostics;
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
/// </summary>
public sealed class BleManager : IDisposable
{
    // 16-bit GATT UUIDs expand against the Bluetooth base UUID.
    private static readonly Guid ServiceUuid   = BluetoothUuidHelper.FromShortId(0xFFF0);
    private static readonly Guid TelemetryUuid = BluetoothUuidHelper.FromShortId(0xFFF4);
    private static readonly Guid ExtraService  = BluetoothUuidHelper.FromShortId(0xFEBA);
    private const string DeviceName = "NSD Workout";

    private readonly LiveTelemetry _live;
    private readonly Action<Action> _post;   // marshal onto the UI thread

    private BluetoothLEAdvertisementWatcher? _watcher;
    private BluetoothLEDevice? _device;
    private readonly List<GattCharacteristic> _subscribed = new();
    private bool _connecting;

    public BleManager(LiveTelemetry live, Action<Action> post)
    {
        _live = live;
        _post = post;
    }

    public void Start()
    {
        _watcher = new BluetoothLEAdvertisementWatcher
        {
            ScanningMode = BluetoothLEScanningMode.Active
        };
        _watcher.AdvertisementFilter.Advertisement.ServiceUuids.Add(ServiceUuid);
        _watcher.Received += OnAdvertisementReceived;
        _watcher.Start();
    }

    private void RestartScan()
    {
        try
        {
            if (_watcher is { Status: BluetoothLEAdvertisementWatcherStatus.Stopped })
                _watcher.Start();
        }
        catch (Exception ex) { Debug.WriteLine($"[BLE] restart scan failed: {ex.Message}"); }
    }

    private async void OnAdvertisementReceived(
        BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args)
    {
        if (_connecting || _device is not null) return;
        if (args.Advertisement.LocalName != DeviceName) return;

        _connecting = true;
        sender.Stop();

        try
        {
            var device = await BluetoothLEDevice.FromBluetoothAddressAsync(args.BluetoothAddress);
            if (device is null) { _connecting = false; RestartScan(); return; }

            _device = device;
            device.ConnectionStatusChanged += OnConnectionStatusChanged;
            await DiscoverAsync(device);

            _post(() => _live.SetConnected(true));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[BLE] connect failed: {ex.Message}");
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
        var svc = await device.GetGattServicesForUuidAsync(service);
        if (svc.Status != GattCommunicationStatus.Success) return;

        foreach (var s in svc.Services)
        {
            var chars = await s.GetCharacteristicsForUuidAsync(characteristic);
            if (chars.Status != GattCommunicationStatus.Success) continue;
            foreach (var c in chars.Characteristics)
                await EnableNotify(c);
        }
    }

    private async Task SubscribeAllNotifiable(BluetoothLEDevice device, Guid service)
    {
        var svc = await device.GetGattServicesForUuidAsync(service);
        if (svc.Status != GattCommunicationStatus.Success) return;

        foreach (var s in svc.Services)
        {
            var chars = await s.GetCharacteristicsAsync();
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

        var status = await c.WriteClientCharacteristicConfigurationDescriptorAsync(value);
        if (status != GattCommunicationStatus.Success) return;

        c.ValueChanged += OnCharacteristicValueChanged;
        _subscribed.Add(c);
    }

    private void OnCharacteristicValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args)
    {
        var data = ReadBytes(args.CharacteristicValue);
        RawLog.Append(sender.Uuid, data);

        if (sender.Uuid != TelemetryUuid) return;
        var now = DateTime.Now;
        _post(() => _live.HandlePacket(data, now));
    }

    private void OnConnectionStatusChanged(BluetoothLEDevice sender, object args)
    {
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

        if (_device is not null)
        {
            _device.ConnectionStatusChanged -= OnConnectionStatusChanged;
            _device.Dispose();
            _device = null;
        }
    }

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
    private static readonly string Path = BuildPath();

    private static string BuildPath()
    {
        var dir = System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Gyroball", "Logs");
        Directory.CreateDirectory(dir);
        return System.IO.Path.Combine(dir, "raw.log");
    }

    public static void Append(Guid uuid, byte[] data)
    {
        try
        {
            var hex = Convert.ToHexString(data);
            var spaced = string.Join(' ', Enumerable.Range(0, data.Length).Select(i => hex.Substring(i * 2, 2)));
            var line = $"{DateTime.Now:HH:mm:ss.fff} {uuid} {spaced}{Environment.NewLine}";
            lock (Gate) File.AppendAllText(Path, line);
        }
        catch { /* logging is best-effort */ }
    }
}
