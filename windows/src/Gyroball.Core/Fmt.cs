using System.Globalization;

namespace Gyroball.Core;

/// <summary>Display formatting helpers, ported from Fmt in WorkoutSession.swift.</summary>
public static class Fmt
{
    private static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

    public static string Revs(double r) =>
        r >= 10_000
            ? (r / 1000).ToString("0.0", Inv) + "k"
            : r.ToString("0", Inv);

    public static string Time(double seconds)
    {
        int s = (int)seconds;
        return s >= 3600
            ? string.Format(Inv, "{0}:{1:00}:{2:00}", s / 3600, (s / 60) % 60, s % 60)
            : string.Format(Inv, "{0}:{1:00}", s / 60, s % 60);
    }

    public static string Rpm(double r) => r.ToString("0", Inv);

    /// <summary>Medium date + short time with relative "Today/Yesterday" naming.</summary>
    public static string SessionDate(DateTime local)
    {
        var today = DateTime.Today;
        var day = local.Date;
        string datePart =
            day == today ? "Today" :
            day == today.AddDays(-1) ? "Yesterday" :
            local.ToString("MMM d, yyyy", CultureInfo.CurrentCulture);
        return $"{datePart} at {local.ToString("h:mm tt", CultureInfo.CurrentCulture)}";
    }
}
