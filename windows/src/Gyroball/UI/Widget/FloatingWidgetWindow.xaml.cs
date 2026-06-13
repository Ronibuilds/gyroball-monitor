using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Gyroball.Core.Settings;
using Gyroball.ViewModels;

namespace Gyroball.UI.Widget;

/// <summary>
/// Auto-appearing translucent overlay, ported from FloatingPanel(Controller/View).swift.
/// Shows when the ball connects, collapses to a compact RPM readout, and expands on
/// hover (or when pinned). Bottom-right anchored so it grows upward. Draggable;
/// position and pin state persist via <see cref="AppSettings"/>.
/// </summary>
public partial class FloatingWidgetWindow : Window
{
    private const double CompactHeight = 122;
    private const double ExpandedHeight = 330;
    private const double WidgetWidth = 200;
    private const double ScreenMargin = 20;

    public static readonly DependencyProperty IsExpandedProperty = DependencyProperty.Register(
        nameof(IsExpanded), typeof(bool), typeof(FloatingWidgetWindow), new PropertyMetadata(false));

    public static readonly DependencyProperty IsPinnedProperty = DependencyProperty.Register(
        nameof(IsPinned), typeof(bool), typeof(FloatingWidgetWindow),
        new PropertyMetadata(false, OnIsPinnedChanged));

    public bool IsExpanded
    {
        get => (bool)GetValue(IsExpandedProperty);
        set => SetValue(IsExpandedProperty, value);
    }

    public bool IsPinned
    {
        get => (bool)GetValue(IsPinnedProperty);
        set => SetValue(IsPinnedProperty, value);
    }

    private readonly AppViewModel _vm;
    private readonly AppSettings _settings;
    private readonly DispatcherTimer _hoverTimer;
    private DateTime? _hoverExitedAt;

    public FloatingWidgetWindow(AppViewModel vm, AppSettings settings)
    {
        InitializeComponent();
        _vm = vm;
        _settings = settings;
        DataContext = vm;

        IsPinned = settings.WidgetPinned;

        _hoverTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(100) };
        _hoverTimer.Tick += (_, _) => CheckHover();

        _vm.PropertyChanged += OnViewModelChanged;
        Loaded += (_, _) => PositionWindow(CompactHeight);
    }

    // MARK: - Connect / disconnect drives visibility

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(AppViewModel.IsConnected)) return;
        if (_vm.IsConnected) ShowWidget();
        else HideWidget();
    }

    private void ShowWidget()
    {
        if (Visibility == Visibility.Visible) return;
        PositionWindow(IsPinned ? ExpandedHeight : CompactHeight);
        if (IsPinned) Expand();

        Opacity = 0;
        Visibility = Visibility.Visible;
        Show();
        BeginAnimation(OpacityProperty, Fade(0, 1, 0.35));
        _hoverTimer.Start();
    }

    private void HideWidget()
    {
        if (Visibility != Visibility.Visible) return;
        _hoverTimer.Stop();
        _hoverExitedAt = null;

        var anim = Fade(Opacity, 0, 0.4);
        anim.Completed += (_, _) =>
        {
            Visibility = Visibility.Collapsed;
            Collapse();
        };
        BeginAnimation(OpacityProperty, anim);
    }

    private static DoubleAnimation Fade(double from, double to, double seconds) =>
        new(from, to, new Duration(TimeSpan.FromSeconds(seconds)))
        {
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };

    // MARK: - Hover tracking (polling, mirrors the macOS approach + hysteresis)

    private void CheckHover()
    {
        if (IsPinned)
        {
            _hoverExitedAt = null;
            if (!IsExpanded) Expand();
            return;
        }

        bool inside = IsMouseInsideWindow();
        if (inside)
        {
            _hoverExitedAt = null;
            if (!IsExpanded) Expand();
        }
        else if (IsExpanded)
        {
            if (_hoverExitedAt is { } exited)
            {
                if ((DateTime.Now - exited).TotalSeconds > 0.25) Collapse();
            }
            else
            {
                _hoverExitedAt = DateTime.Now;
            }
        }
    }

    private bool IsMouseInsideWindow()
    {
        var p = PointToScreen(Mouse.GetPosition(this));
        return p.X >= Left && p.X <= Left + ActualWidth &&
               p.Y >= Top && p.Y <= Top + ActualHeight;
    }

    // MARK: - Expansion (bottom-anchored: keep the bottom edge fixed, grow upward)

    private void Expand()
    {
        AnchorToBottom(ExpandedHeight);
        IsExpanded = true;
    }

    private void Collapse()
    {
        _hoverExitedAt = null;
        IsExpanded = false;
        AnchorToBottom(CompactHeight);
    }

    private void AnchorToBottom(double newHeight)
    {
        double bottom = Top + Height;
        Height = newHeight;
        Top = bottom - newHeight;
    }

    // MARK: - Positioning + persistence

    private void PositionWindow(double height)
    {
        var area = SystemParameters.WorkArea;
        double left = area.Right - WidgetWidth - ScreenMargin;
        double bottom = area.Bottom - ScreenMargin;

        if (_settings.WidgetX is { } sx && _settings.WidgetY is { } sy)
        {
            var probe = new Rect(sx, sy - CompactHeight, WidgetWidth, CompactHeight);
            if (area.IntersectsWith(probe)) { left = sx; bottom = sy; }
        }

        Width = WidgetWidth;
        Height = height;
        Left = left;
        Top = bottom - height;
    }

    private void OnCardMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left) return;
        DragMove();
        // Persist the compact-equivalent anchor (left + bottom) so expand/restore agree.
        _settings.WidgetX = Left;
        _settings.WidgetY = Top + Height;
        _settings.Save();
    }

    private static void OnIsPinnedChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var self = (FloatingWidgetWindow)d;
        bool pinned = (bool)e.NewValue;
        self._settings.WidgetPinned = pinned;
        self._settings.Save();

        // Before the window is shown its geometry is NaN; ShowWidget() handles the
        // initial pinned layout, so only react to live toggles here.
        if (!self.IsLoaded || self.Visibility != Visibility.Visible) return;

        if (pinned) self.Expand();
        else if (!self.IsMouseInsideWindow()) self.Collapse();
    }

    protected override void OnClosed(EventArgs e)
    {
        _hoverTimer.Stop();
        _vm.PropertyChanged -= OnViewModelChanged;
        base.OnClosed(e);
    }
}
