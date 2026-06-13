using Gyroball.Core;
using Xunit;

namespace Gyroball.Tests;

public class FmtTests
{
    [Theory]
    [InlineData(0, "0")]
    [InlineData(999, "999")]
    [InlineData(9999, "9999")]
    [InlineData(10000, "10.0k")]
    [InlineData(12345, "12.3k")]
    public void Revs_UsesKSuffixAt10k(double input, string expected)
    {
        Assert.Equal(expected, Fmt.Revs(input));
    }

    [Theory]
    [InlineData(0, "0:00")]
    [InlineData(5, "0:05")]
    [InlineData(65, "1:05")]
    [InlineData(599, "9:59")]
    [InlineData(3600, "1:00:00")]
    [InlineData(3661, "1:01:01")]
    public void Time_SwitchesToHoursAt3600(double seconds, string expected)
    {
        Assert.Equal(expected, Fmt.Time(seconds));
    }

    [Theory]
    [InlineData(1694.4, "1694")]
    [InlineData(3920.0, "3920")]
    public void Rpm_RoundsToWhole(double input, string expected)
    {
        Assert.Equal(expected, Fmt.Rpm(input));
    }

    [Fact]
    public void Zone_Thresholds()
    {
        Assert.Equal(ZoneColor.Warmup, Zones.Zone(3499));
        Assert.Equal(ZoneColor.Steady, Zones.Zone(3500));
        Assert.Equal(ZoneColor.Steady, Zones.Zone(4499));
        Assert.Equal(ZoneColor.Hard, Zones.Zone(4500));
        Assert.Equal(ZoneColor.Hard, Zones.Zone(5999));
        Assert.Equal(ZoneColor.Intense, Zones.Zone(6000));
        Assert.Equal(ZoneColor.Intense, Zones.Zone(6999));
        Assert.Equal(ZoneColor.Max, Zones.Zone(7000));
        Assert.Equal(ZoneColor.Max, Zones.Zone(99999));
    }
}
