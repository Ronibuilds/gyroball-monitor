using System.Windows;
using System.Windows.Controls;
using Gyroball.Core;
using Gyroball.ViewModels;
using LiveChartsCore;
using LiveChartsCore.SkiaSharpView;
using LiveChartsCore.SkiaSharpView.Painting;
using SkiaSharp;

namespace Gyroball.UI.Dashboard;

public partial class OverviewView : UserControl
{
    private AppViewModel? _vm;

    public OverviewView()
    {
        InitializeComponent();
        Loaded += (_, _) => Bind();
        DataContextChanged += (_, _) => Bind();
    }

    private static readonly SKColor Cyan = new(50, 200, 235);
    private static readonly SKColor Blue = new(10, 132, 255);

    private void Bind()
    {
        if (DataContext is not AppViewModel vm || ReferenceEquals(vm, _vm)) return;
        if (_vm is not null) _vm.Store.PropertyChanged -= OnStoreChanged;
        _vm = vm;
        _vm.Store.PropertyChanged += OnStoreChanged;

        BuildLiveChart();
        RefreshStoreVisuals();
    }

    private void OnStoreChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        => Dispatcher.BeginInvoke(RefreshStoreVisuals);

    private void BuildLiveChart()
    {
        if (_vm is null) return;

        // RpmHistory is an ObservableCollection<double>; LiveCharts updates it live.
        LiveChart.Series = new ISeries[]
        {
            new LineSeries<double>
            {
                Values = _vm.Live.RpmHistory,
                GeometrySize = 0,
                LineSmoothness = 0.6,
                Stroke = new SolidColorPaint(Cyan) { StrokeThickness = 2 },
                Fill = new LinearGradientPaint(
                    new[] { Cyan.WithAlpha(80), Cyan.WithAlpha(0) },
                    new SKPoint(0, 0), new SKPoint(0, 1))
            }
        };
        LiveChart.XAxes = new[] { new Axis { IsVisible = false } };
        LiveChart.YAxes = new[] { Hidden() };
    }

    private void RefreshStoreVisuals()
    {
        if (_vm is null) return;

        var history = _vm.Store.DailyHistory();
        DailyChart.Series = new ISeries[]
        {
            new ColumnSeries<double>
            {
                Values = history.Select(h => h.Revs).ToArray(),
                Fill = new LinearGradientPaint(new[] { Cyan, Blue }, new SKPoint(0, 0), new SKPoint(0, 1)),
                Rx = 4,
                Ry = 4
            }
        };
        DailyChart.XAxes = new[]
        {
            new Axis
            {
                Labels = history.Select(h => h.Day.ToString("MMM d")).ToArray(),
                LabelsRotation = 0,
                TextSize = 10,
                LabelsPaint = new SolidColorPaint(new SKColor(142, 142, 147))
            }
        };
        DailyChart.YAxes = new[] { Hidden() };

        LongestCard.Value = Fmt.Time(_vm.Store.LongestSession?.Duration ?? 0);
    }

    private static Axis Hidden() => new()
    {
        IsVisible = false,
        MinLimit = null
    };
}
