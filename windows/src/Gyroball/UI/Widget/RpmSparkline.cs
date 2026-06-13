using System.Collections.Specialized;
using System.Windows;
using System.Windows.Media;

namespace Gyroball.UI.Widget;

/// <summary>
/// The widget's mini RPM graph, ported from RPMGraphView.swift. Plots the rolling
/// history with a filled area, a stroked line, and a live dot at the latest point.
/// The vertical scale floats: min = 0.5·max, so small wobbles stay visible.
/// </summary>
public sealed class RpmSparkline : FrameworkElement
{
    public static readonly DependencyProperty HistoryProperty = DependencyProperty.Register(
        nameof(History), typeof(IEnumerable<double>), typeof(RpmSparkline),
        new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.AffectsRender, OnHistoryChanged));

    public static readonly DependencyProperty TintProperty = DependencyProperty.Register(
        nameof(Tint), typeof(Brush), typeof(RpmSparkline),
        new FrameworkPropertyMetadata(Brushes.Gray, FrameworkPropertyMetadataOptions.AffectsRender));

    public IEnumerable<double>? History
    {
        get => (IEnumerable<double>?)GetValue(HistoryProperty);
        set => SetValue(HistoryProperty, value);
    }

    public Brush Tint
    {
        get => (Brush)GetValue(TintProperty);
        set => SetValue(TintProperty, value);
    }

    private static void OnHistoryChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var self = (RpmSparkline)d;
        if (e.OldValue is INotifyCollectionChanged oldC) oldC.CollectionChanged -= self.OnCollectionChanged;
        if (e.NewValue is INotifyCollectionChanged newC) newC.CollectionChanged += self.OnCollectionChanged;
        self.InvalidateVisual();
    }

    private void OnCollectionChanged(object? s, NotifyCollectionChangedEventArgs e) =>
        Dispatcher.BeginInvoke(InvalidateVisual);

    protected override void OnRender(DrawingContext ctx)
    {
        var data = History?.ToList();
        if (data is null || data.Count < 2) return;

        double w = ActualWidth, h = ActualHeight;
        double maxVal = data.Max();
        double minVal = maxVal * 0.5;
        double range = maxVal - minVal;
        if (range <= 0) return;

        double step = w / (data.Count - 1);

        Point At(int i)
        {
            double x = i * step;
            double y = h * (1 - (data[i] - minVal) / range);
            return new Point(x, Math.Max(0, Math.Min(h, y)));
        }

        var line = new StreamGeometry();
        using (var g = line.Open())
        {
            g.BeginFigure(At(0), isFilled: false, isClosed: false);
            for (int i = 1; i < data.Count; i++) g.LineTo(At(i), isStroked: true, isSmoothJoin: true);
        }
        line.Freeze();

        var fill = new StreamGeometry();
        using (var g = fill.Open())
        {
            g.BeginFigure(At(0), isFilled: true, isClosed: true);
            for (int i = 1; i < data.Count; i++) g.LineTo(At(i), true, true);
            g.LineTo(new Point(w, h), false, false);
            g.LineTo(new Point(0, h), false, false);
        }
        fill.Freeze();

        var fillBrush = Tint.Clone();
        fillBrush.Opacity = 0.12;
        ctx.DrawGeometry(fillBrush, null, fill);
        ctx.DrawGeometry(null, new Pen(Tint, 1.5) { LineJoin = PenLineJoin.Round, StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round }, line);

        var lastPt = At(data.Count - 1);
        ctx.DrawEllipse(Tint, null, lastPt, 3, 3);
    }
}
