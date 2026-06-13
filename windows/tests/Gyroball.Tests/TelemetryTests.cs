using Gyroball.Core;
using Xunit;

namespace Gyroball.Tests;

public class TelemetryTests
{
    [Fact]
    public void RawValue_ReadsBytes2And3BigEndian()
    {
        // 00 00 | 5B 91 (=23441) | 00 00 | 00 00
        var packet = new byte[] { 0x00, 0x00, 0x5B, 0x91, 0x00, 0x00, 0x00, 0x00 };
        Assert.Equal((ushort)23441, Telemetry.RawValue(packet));
    }

    [Fact]
    public void RawValue_ShortPacket_ReturnsNull()
    {
        Assert.Null(Telemetry.RawValue(new byte[] { 0x00, 0x00, 0x5B }));
    }

    [Theory]
    // Calibration points from notes/protocol.md, within the documented tolerance.
    [InlineData((ushort)23441, 1694, 1.0)]   // +0.7%
    [InlineData((ushort)10213, 3920, 1.0)]   // -0.1%
    public void RpmFromRaw_MatchesNsdAppWithinTolerance(ushort raw, double appRpm, double tolerancePercent)
    {
        var rpm = Telemetry.RpmFromRaw(raw);
        Assert.NotNull(rpm);
        var errorPercent = Math.Abs(rpm!.Value - appRpm) / appRpm * 100;
        Assert.True(errorPercent <= tolerancePercent, $"error {errorPercent:F2}% exceeded {tolerancePercent}%");
    }

    [Fact]
    public void RpmFromRaw_ExactFormula()
    {
        Assert.Equal(40_000_000.0 / 10000, Telemetry.RpmFromRaw(10000));
    }

    [Theory]
    [InlineData((ushort)800)]   // boundary: not > 800
    [InlineData((ushort)0)]
    [InlineData((ushort)500)]
    public void RpmFromRaw_GlitchReadings_ReturnNull(ushort raw)
    {
        Assert.Null(Telemetry.RpmFromRaw(raw));
    }

    [Fact]
    public void RpmFromRaw_JustAboveThreshold_IsValid()
    {
        Assert.NotNull(Telemetry.RpmFromRaw(801));
    }

    [Fact]
    public void DecodeRpm_FullPacket()
    {
        var packet = new byte[] { 0x00, 0x00, 0x27, 0xE5, 0x00, 0x00, 0x01, 0x42 }; // raw 10213
        var rpm = Telemetry.DecodeRpm(packet);
        Assert.NotNull(rpm);
        Assert.Equal(40_000_000.0 / 10213, rpm!.Value, 3);
    }
}
