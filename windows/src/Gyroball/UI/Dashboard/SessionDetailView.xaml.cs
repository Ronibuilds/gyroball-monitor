using System.Windows;
using System.Windows.Controls;
using Gyroball.Core;
using Gyroball.Core.Storage;
using LiveChartsCore;
using LiveChartsCore.SkiaSharpView;
using LiveChartsCore.SkiaSharpView.Painting;
using SkiaSharp;

namespace Gyroball.UI.Dashboard;

/// <summary>A single session's detail page, ported from SessionDetailView.swift.</summary>
public partial class SessionDetailView : UserControl
{
    private readonly WorkoutSession _session;
    private readonly SessionStore _store;
    private readonly Action _onDelete;

    private static readonly SKColor Cyan = new(50, 200, 235);
    private static readonly SKColor Blue = new(10, 132, 255);

    public SessionDetailView(WorkoutSession session, SessionStore store, Action onDelete)
    {
        InitializeComponent();
        _session = session;
        _store = store;
        _onDelete = onDelete;

        DateText.Text = Fmt.SessionDate(session.StartedAt);
        TopCard.Value = $"{Fmt.Rpm(session.TopRpm)} rpm";
        AvgCard.Value = $"{Fmt.Rpm(session.AvgRpm)} rpm";
        RevsCard.Value = Fmt.Revs(session.Revolutions);
        DurationCard.Value = Fmt.Time(session.Duration);

        BuildChart();
    }

    private void BuildChart()
    {
        if (_session.Samples.Count < 2)
        {
            ChartTitle.Visibility = Visibility.Collapsed;
            ChartCard.Visibility = Visibility.Collapsed;
            return;
        }

        SessionChart.Series = new ISeries[]
        {
            new LineSeries<double>
            {
                Values = _session.Samples.ToArray(),
                GeometrySize = 0,
                LineSmoothness = 0.6,
                Stroke = new SolidColorPaint(Blue) { StrokeThickness = 2 },
                Fill = new LinearGradientPaint(
                    new[] { Cyan.WithAlpha(80), Cyan.WithAlpha(0) },
                    new SKPoint(0, 0), new SKPoint(0, 1))
            }
        };
        SessionChart.XAxes = new[]
        {
            new Axis { Name = "seconds", TextSize = 10, LabelsPaint = new SolidColorPaint(new SKColor(142, 142, 147)) }
        };
        SessionChart.YAxes = new[] { new Axis { TextSize = 10, LabelsPaint = new SolidColorPaint(new SKColor(142, 142, 147)) } };
    }

    private void OnDelete(object sender, RoutedEventArgs e)
    {
        _store.Delete(_session);
        _onDelete();
    }
}
