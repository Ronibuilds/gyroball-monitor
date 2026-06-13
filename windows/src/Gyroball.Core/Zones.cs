namespace Gyroball.Core;

/// <summary>Effort zone for an RPM value — drives widget/chart tinting.</summary>
public enum ZoneColor
{
    Warmup,   // green
    Steady,   // blue
    Hard,     // yellow
    Intense,  // orange
    Max       // red
}

public static class Zones
{
    /// User-tuned RPM zone thresholds (ported from Fmt.zone / ZoneStyle.swift).
    public static ZoneColor Zone(double rpm) => rpm switch
    {
        < 3500 => ZoneColor.Warmup,
        < 4500 => ZoneColor.Steady,
        < 6000 => ZoneColor.Hard,
        < 7000 => ZoneColor.Intense,
        _      => ZoneColor.Max
    };
}
