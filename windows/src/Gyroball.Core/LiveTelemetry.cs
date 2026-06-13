using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;

namespace Gyroball.Core;

/// <summary>
/// Live workout state, observable for data binding. This is the C# home of the
/// macOS BLEManager's @Published surface plus its handleRPM accumulation logic
/// — kept platform-free so it unit-tests without any Bluetooth stack.
///
/// The BLE transport calls <see cref="HandlePacket"/> for every FFF4 packet and
/// <see cref="Tick"/> on a periodic timer; both take an explicit "now" so tests
/// drive time directly.
/// </summary>
public sealed partial class LiveTelemetry : ObservableObject
{
    private const int HistoryLimit = 60;
    private const double InactivityTimeout = 3.0;   // seconds without packets ⇒ idle
    private const double AccumulationGap = 2.0;      // gaps beyond this don't count as workout

    [ObservableProperty] private double _rpm;
    [ObservableProperty] private double _topSpeed;
    [ObservableProperty] private double _totalRevolutions;
    [ObservableProperty] private double _activeSeconds;
    [ObservableProperty] private bool _isActive;
    [ObservableProperty] private bool _isConnected;
    [ObservableProperty] private ushort _lastRawValue;

    /// <summary>Rolling RPM history (max 60 samples) for the live sparkline/graph.</summary>
    public ObservableCollection<double> RpmHistory { get; } = new();

    /// <summary>Raised once per decoded packet with (RPM, timestamp) — drives session tracking.</summary>
    public event Action<double, DateTime>? PacketTick;

    private DateTime? _lastUpdateTime;

    public double AverageRpm => ActiveSeconds > 1 ? TotalRevolutions / ActiveSeconds * 60 : 0;

    /// <summary>Decode + accumulate a raw FFF4 packet. Returns false if the packet was a glitch.</summary>
    public bool HandlePacket(ReadOnlySpan<byte> data, DateTime now)
    {
        var rpm = Telemetry.DecodeRpm(data);
        var raw = Telemetry.RawValue(data);
        if (rpm is null || raw is null) return false;
        HandleRpm(rpm.Value, raw.Value, now);
        return true;
    }

    public void HandleRpm(double rpm, ushort raw, DateTime now)
    {
        LastRawValue = raw;

        // Only accumulate over continuous packet streams; gaps mean the ball was
        // disconnected or idle and shouldn't count as workout time.
        if (_lastUpdateTime is { } prev)
        {
            var dt = (now - prev).TotalSeconds;
            if (dt < AccumulationGap)
            {
                TotalRevolutions += (Rpm + rpm) / 2.0 / 60.0 * dt;
                ActiveSeconds += dt;
            }
        }
        _lastUpdateTime = now;

        Rpm = rpm;
        TopSpeed = Math.Max(TopSpeed, rpm);
        IsActive = true;
        OnPropertyChanged(nameof(AverageRpm));

        PacketTick?.Invoke(rpm, now);

        RpmHistory.Add(rpm);
        while (RpmHistory.Count > HistoryLimit) RpmHistory.RemoveAt(0);
    }

    /// <summary>Periodic tick — flips the widget to idle after a quiet gap.</summary>
    public void Tick(DateTime now)
    {
        if (IsActive && _lastUpdateTime is { } last &&
            (now - last).TotalSeconds >= InactivityTimeout)
        {
            IsActive = false;
        }
    }

    public void SetConnected(bool connected)
    {
        IsConnected = connected;
        if (!connected) IsActive = false;
    }

    /// <summary>Clears live counters for a new session (mirrors BLEManager.resetSession).</summary>
    public void ResetSession()
    {
        Rpm = 0;
        TopSpeed = 0;
        TotalRevolutions = 0;
        ActiveSeconds = 0;
        IsActive = false;
        LastRawValue = 0;
        RpmHistory.Clear();
        _lastUpdateTime = null;
        OnPropertyChanged(nameof(AverageRpm));
    }

    partial void OnTotalRevolutionsChanged(double value) => OnPropertyChanged(nameof(AverageRpm));
    partial void OnActiveSecondsChanged(double value) => OnPropertyChanged(nameof(AverageRpm));
}
