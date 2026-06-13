using Gyroball.Core;
using Gyroball.Core.Storage;
using Xunit;

namespace Gyroball.Tests;

public class SessionTrackerTests : IDisposable
{
    private readonly string _dbPath = Path.Combine(Path.GetTempPath(), $"gyro-track-{Guid.NewGuid():N}.sqlite");
    private readonly SessionStore _store;
    private readonly LiveTelemetry _live = new();
    private readonly SessionTracker _tracker;

    public SessionTrackerTests()
    {
        _store = new SessionStore(_dbPath);
        _tracker = new SessionTracker(_live, _store);
    }

    /// Drives a steady spin into the live telemetry + tracker over [seconds] one-second steps.
    private void Spin(double rpm, int seconds, DateTime start)
    {
        for (int i = 0; i <= seconds; i++)
        {
            var now = start.AddSeconds(i);
            _live.HandleRpm(rpm, 10000, now);   // raises PacketTick → tracker.HandleTick
        }
    }

    [Fact]
    public void RealWorkout_IsPersistedAfterGrace()
    {
        var t0 = new DateTime(2026, 1, 1, 12, 0, 0);
        Spin(6000, 30, t0);                          // ~3000 revolutions, well over the 30 minimum
        Assert.Empty(_store.Sessions);               // not yet closed

        _tracker.CheckGrace(t0.AddSeconds(30 + 45));  // grace elapsed
        Assert.Single(_store.Sessions);

        var s = _store.Sessions[0];
        Assert.Equal(t0, s.StartedAt);
        Assert.True(s.Revolutions > 30);
        Assert.Equal(6000, s.TopRpm);
    }

    [Fact]
    public void TrivialSpin_BelowMinimumRevolutions_IsDiscarded()
    {
        var t0 = new DateTime(2026, 1, 1, 12, 0, 0);
        Spin(4000, 0, t0);                            // a single packet, ~0 revolutions accumulated
        _tracker.CheckGrace(t0.AddSeconds(46));
        Assert.Empty(_store.Sessions);
    }

    [Fact]
    public void GraceNotElapsed_KeepsSessionOpen()
    {
        var t0 = new DateTime(2026, 1, 1, 12, 0, 0);
        Spin(6000, 30, t0);
        _tracker.CheckGrace(t0.AddSeconds(30 + 44));  // just under grace
        Assert.Empty(_store.Sessions);
    }

    [Fact]
    public void TwoSpinsWithinGrace_CountAsOneSession()
    {
        var t0 = new DateTime(2026, 1, 1, 12, 0, 0);
        Spin(6000, 15, t0);
        // resume 20s later — within the 45s grace, so same session.
        // Last packet lands at t0+50; close 45s after that.
        Spin(6000, 15, t0.AddSeconds(35));
        _tracker.CheckGrace(t0.AddSeconds(50 + 46));

        Assert.Single(_store.Sessions);
    }

    [Fact]
    public void Samples_AreCollectedRoughlyOncePerSecond()
    {
        var t0 = new DateTime(2026, 1, 1, 12, 0, 0);
        Spin(6000, 10, t0);
        _tracker.CheckGrace(t0.AddSeconds(60));

        var s = _store.Sessions[0];
        Assert.InRange(s.Samples.Count, 10, 12);     // ~1 Hz over 10–11 seconds
    }

    [Fact]
    public void Discard_DropsSessionWithoutSaving()
    {
        var t0 = new DateTime(2026, 1, 1, 12, 0, 0);
        Spin(6000, 30, t0);
        _tracker.Discard();
        _tracker.CheckGrace(t0.AddSeconds(120));
        Assert.Empty(_store.Sessions);
        Assert.Equal(0, _live.TotalRevolutions);     // live counters reset too
    }

    public void Dispose()
    {
        _store.Dispose();
        if (File.Exists(_dbPath)) File.Delete(_dbPath);
    }
}
