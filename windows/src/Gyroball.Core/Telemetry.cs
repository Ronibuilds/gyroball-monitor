namespace Gyroball.Core;

/// <summary>
/// Decodes the NSD Powerball's FFF4 telemetry packet into RPM.
/// Ported verbatim from the macOS app's Telemetry.swift — same constant,
/// same calibration (raw 23441 → 1694 RPM, raw 10213 → 3920 RPM).
/// </summary>
public static class Telemetry
{
    // FFF4 packet (8 bytes): 00 00 | period uint16 BE | 00 00 | flag, counter
    // The raw value is the rotation period in 4 MHz timer ticks, so speed is
    // its inverse: RPM = 40e6 / raw.
    public const double PeriodConstant = 40_000_000.0;

    /// <summary>RPM from a raw period value, or null for glitch readings.</summary>
    public static double? RpmFromRaw(ushort raw)
    {
        // Below ~800 the implied speed exceeds 60k RPM — a glitch, not a reading.
        if (raw <= 800) return null;
        return PeriodConstant / raw;
    }

    /// <summary>Big-endian rotation period from bytes 2–3 of the packet.</summary>
    public static ushort? RawValue(ReadOnlySpan<byte> data)
    {
        if (data.Length < 4) return null;
        return (ushort)((data[2] << 8) | data[3]);
    }

    public static double? DecodeRpm(ReadOnlySpan<byte> data)
    {
        var raw = RawValue(data);
        return raw is null ? null : RpmFromRaw(raw.Value);
    }
}
