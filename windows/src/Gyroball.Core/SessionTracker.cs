using Gyroball.Core.Storage;

namespace Gyroball.Core;

/// <summary>
/// Turns the live packet stream into persisted sessions. A session opens on the
/// first packet and closes after <see cref="GracePeriod"/> without packets, so
/// the ball dropping BLE below ~1700 RPM and being spun back up shortly after
/// stays within one session. Ported from SessionTracker.swift.
///
/// Grace expiry is driven by <see cref="CheckGrace"/>, which the host calls on a
/// periodic timer; tests call it directly with a chosen "now".
/// </summary>
public sealed class SessionTracker
{
    public const double GracePeriod = 45;          // seconds of silence before a session closes
    public const double MinimumRevolutions = 30;   // ignore trivial spins

    private readonly LiveTelemetry _live;
    private readonly SessionStore _store;

    private DateTime? _sessionStart;
    private DateTime? _lastSampleAt;
    private DateTime? _lastTickAt;
    private readonly List<double> _samples = new();

    public SessionTracker(LiveTelemetry live, SessionStore store)
    {
        _live = live;
        _store = store;
        _live.PacketTick += HandleTick;   // (rpm, timestamp)
    }

    public void HandleTick(double rpm, DateTime now)
    {
        if (_sessionStart is null)
        {
            _sessionStart = now;
            _samples.Clear();
            _lastSampleAt = null;
        }

        if (_lastSampleAt is null || (now - _lastSampleAt.Value).TotalSeconds >= 1.0)
        {
            _samples.Add(rpm);
            _lastSampleAt = now;
        }

        _lastTickAt = now;
    }

    /// <summary>Closes the session if the grace period has elapsed since the last packet.</summary>
    public void CheckGrace(DateTime now)
    {
        if (_sessionStart is null || _lastTickAt is null) return;
        if ((now - _lastTickAt.Value).TotalSeconds >= GracePeriod) FinalizeSession();
    }

    /// <summary>Persists the current session (if it was a real workout) and resets.</summary>
    public void FinalizeSession()
    {
        try
        {
            if (_sessionStart is not { } start) return;
            if (_live.TotalRevolutions < MinimumRevolutions) return;

            _store.Add(new WorkoutSession
            {
                StartedAt = start,
                Duration = _live.ActiveSeconds,
                TopRpm = _live.TopSpeed,
                AvgRpm = _live.AverageRpm,
                Revolutions = _live.TotalRevolutions,
                Samples = _samples.ToArray()
            });
        }
        finally
        {
            Discard();
        }
    }

    /// <summary>Throws away the current session without saving.</summary>
    public void Discard()
    {
        _sessionStart = null;
        _lastSampleAt = null;
        _lastTickAt = null;
        _samples.Clear();
        _live.ResetSession();
    }
}
