using Gyroball.Core;
using Xunit;

namespace Gyroball.Tests;

public class LiveTelemetryTests
{
    private static byte[] Packet(ushort raw) =>
        new byte[] { 0x00, 0x00, (byte)(raw >> 8), (byte)(raw & 0xFF), 0x00, 0x00, 0x00, 0x00 };

    [Fact]
    public void HandlePacket_DecodesAndMarksActive()
    {
        var t = new LiveTelemetry();
        var ok = t.HandlePacket(Packet(10000), new DateTime(2026, 1, 1, 0, 0, 0));
        Assert.True(ok);
        Assert.Equal(4000, t.Rpm);          // 40e6 / 10000
        Assert.True(t.IsActive);
        Assert.Equal((ushort)10000, t.LastRawValue);
    }

    [Fact]
    public void HandlePacket_GlitchReturnsFalse()
    {
        var t = new LiveTelemetry();
        Assert.False(t.HandlePacket(Packet(500), DateTime.Now));
    }

    [Fact]
    public void Accumulation_OverContinuousStream()
    {
        var t = new LiveTelemetry();
        var t0 = new DateTime(2026, 1, 1, 0, 0, 0);
        t.HandleRpm(6000, 6666, t0);                     // first packet: no dt yet
        t.HandleRpm(6000, 6666, t0.AddSeconds(1));       // dt=1s, avg 6000 rpm ⇒ 100 rev

        Assert.Equal(1.0, t.ActiveSeconds, 3);
        Assert.Equal(100.0, t.TotalRevolutions, 3);      // 6000/60 * 1s
        Assert.Equal(6000, t.TopSpeed);
    }

    [Fact]
    public void Accumulation_SkipsLongGaps()
    {
        var t = new LiveTelemetry();
        var t0 = new DateTime(2026, 1, 1, 0, 0, 0);
        t.HandleRpm(6000, 6666, t0);
        t.HandleRpm(6000, 6666, t0.AddSeconds(5));        // dt=5s > 2s gate ⇒ no accumulation

        Assert.Equal(0, t.ActiveSeconds);
        Assert.Equal(0, t.TotalRevolutions);
    }

    [Fact]
    public void AverageRpm_FromAccumulatedTotals()
    {
        var t = new LiveTelemetry();
        var t0 = new DateTime(2026, 1, 1, 0, 0, 0);
        // Steady 3000 rpm over 10 one-second steps ⇒ average converges to 3000.
        for (int i = 0; i <= 10; i++) t.HandleRpm(3000, 13333, t0.AddSeconds(i));

        Assert.True(t.ActiveSeconds > 1);
        Assert.Equal(3000, t.AverageRpm, 3);
        Assert.Equal(t.TotalRevolutions / t.ActiveSeconds * 60, t.AverageRpm, 6);
    }

    [Fact]
    public void Tick_FlipsInactiveAfterTimeout()
    {
        var t = new LiveTelemetry();
        var t0 = new DateTime(2026, 1, 1, 0, 0, 0);
        t.HandleRpm(4000, 10000, t0);
        Assert.True(t.IsActive);

        t.Tick(t0.AddSeconds(2));     // within 3s
        Assert.True(t.IsActive);

        t.Tick(t0.AddSeconds(3.1));   // past 3s
        Assert.False(t.IsActive);
    }

    [Fact]
    public void History_CappedAt60()
    {
        var t = new LiveTelemetry();
        var t0 = new DateTime(2026, 1, 1, 0, 0, 0);
        for (int i = 0; i < 100; i++) t.HandleRpm(4000, 10000, t0.AddSeconds(i * 0.1));
        Assert.Equal(60, t.RpmHistory.Count);
    }

    [Fact]
    public void ResetSession_ClearsEverything()
    {
        var t = new LiveTelemetry();
        var t0 = new DateTime(2026, 1, 1, 0, 0, 0);
        t.HandleRpm(6000, 6666, t0);
        t.HandleRpm(6000, 6666, t0.AddSeconds(1));
        t.ResetSession();

        Assert.Equal(0, t.Rpm);
        Assert.Equal(0, t.TotalRevolutions);
        Assert.Equal(0, t.ActiveSeconds);
        Assert.Equal(0, t.TopSpeed);
        Assert.Empty(t.RpmHistory);
        Assert.False(t.IsActive);
    }

    [Fact]
    public void PacketTick_FiresPerPacket()
    {
        var t = new LiveTelemetry();
        int count = 0;
        t.PacketTick += (_, _) => count++;
        t.HandleRpm(4000, 10000, DateTime.Now);
        t.HandleRpm(4000, 10000, DateTime.Now);
        Assert.Equal(2, count);
    }
}
