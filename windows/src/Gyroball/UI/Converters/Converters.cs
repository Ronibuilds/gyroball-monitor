using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using Gyroball.Core;

namespace Gyroball.UI.Converters;

/// <summary>Shared brushes for the RPM effort zones (matches ZoneStyle.swift palette).</summary>
public static class ZonePalette
{
    public static readonly SolidColorBrush Warmup  = Frozen(0x34, 0xC7, 0x59); // green
    public static readonly SolidColorBrush Steady  = Frozen(0x0A, 0x84, 0xFF); // blue
    public static readonly SolidColorBrush Hard    = Frozen(0xFF, 0xD6, 0x0A); // yellow
    public static readonly SolidColorBrush Intense = Frozen(0xFF, 0x9F, 0x0A); // orange
    public static readonly SolidColorBrush Max     = Frozen(0xFF, 0x45, 0x3A); // red
    public static readonly SolidColorBrush Idle    = Frozen(0x8E, 0x8E, 0x93); // secondary gray

    public static SolidColorBrush For(double rpm) => Zones.Zone(rpm) switch
    {
        ZoneColor.Warmup  => Warmup,
        ZoneColor.Steady  => Steady,
        ZoneColor.Hard    => Hard,
        ZoneColor.Intense => Intense,
        _                 => Max
    };

    private static SolidColorBrush Frozen(byte r, byte g, byte b)
    {
        var brush = new SolidColorBrush(Color.FromRgb(r, g, b));
        brush.Freeze();
        return brush;
    }
}

/// <summary>RPM (double) → zone brush. Pass IsActive via ConverterParameter "idle" to force gray.</summary>
public sealed class ZoneBrushConverter : IValueConverter
{
    public object Convert(object value, Type t, object parameter, CultureInfo c)
    {
        if (parameter as string == "idle") return ZonePalette.Idle;
        return value is double rpm ? ZonePalette.For(rpm) : ZonePalette.Idle;
    }
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

/// <summary>Status level (0 gray / 1 yellow / 2 green) → brush.</summary>
public sealed class StatusBrushConverter : IValueConverter
{
    public object Convert(object value, Type t, object parameter, CultureInfo c) =>
        value is int level
            ? level switch { 2 => ZonePalette.Warmup, 1 => ZonePalette.Hard, _ => ZonePalette.Idle }
            : ZonePalette.Idle;
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

public sealed class RevsConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) =>
        value is double d ? Fmt.Revs(d) : "0";
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

public sealed class TimeConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) =>
        value is double d ? Fmt.Time(d) : "0:00";
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

public sealed class RpmConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) =>
        value is double d ? Fmt.Rpm(d) : "0";
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

public sealed class SessionDateConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) =>
        value is DateTime dt ? Fmt.SessionDate(dt) : "";
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

/// <summary>A WorkoutSession → "1.2k revs · 5:30 · top 6200" summary line for the sidebar.</summary>
public sealed class SessionSummaryConverter : IValueConverter
{
    public object Convert(object value, Type t, object p, CultureInfo c) =>
        value is WorkoutSession s
            ? $"{Fmt.Revs(s.Revolutions)} revs · {Fmt.Time(s.Duration)} · top {Fmt.Rpm(s.TopRpm)}"
            : "";
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

/// <summary>bool → Visibility. ConverterParameter "invert" flips it.</summary>
public sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type t, object parameter, CultureInfo c)
    {
        var b = value is bool v && v;
        if (parameter as string == "invert") b = !b;
        return b ? Visibility.Visible : Visibility.Collapsed;
    }
    public object ConvertBack(object value, Type t, object p, CultureInfo c) => Binding.DoNothing;
}

/// <summary>(isActive, rpm) → the big RPM string, or "—" when idle.</summary>
public sealed class ActiveRpmConverter : IMultiValueConverter
{
    public object Convert(object[] values, Type t, object p, CultureInfo c)
    {
        if (values.Length >= 2 && values[0] is bool active && values[1] is double rpm)
            return active ? Fmt.Rpm(rpm) : "—";
        return "—";
    }
    public object[] ConvertBack(object value, Type[] t, object p, CultureInfo c) => Array.Empty<object>();
}

/// <summary>(isActive, rpm) → zone brush, gray when idle.</summary>
public sealed class ActiveZoneBrushConverter : IMultiValueConverter
{
    public object Convert(object[] values, Type t, object p, CultureInfo c)
    {
        if (values.Length >= 2 && values[0] is bool active && values[1] is double rpm && active)
            return ZonePalette.For(rpm);
        return ZonePalette.Idle;
    }
    public object[] ConvertBack(object value, Type[] t, object p, CultureInfo c) => Array.Empty<object>();
}
