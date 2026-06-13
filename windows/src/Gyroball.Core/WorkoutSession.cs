namespace Gyroball.Core;

/// <summary>A persisted workout, mirroring WorkoutSession.swift.</summary>
public sealed record WorkoutSession
{
    public long Id { get; init; }
    public DateTime StartedAt { get; init; }
    public double Duration { get; init; }
    public double TopRpm { get; init; }
    public double AvgRpm { get; init; }
    public double Revolutions { get; init; }

    /// <summary>RPM sampled at ~1 Hz over the active part of the session.</summary>
    public IReadOnlyList<double> Samples { get; init; } = Array.Empty<double>();
}
