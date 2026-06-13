using System.Threading;
using System.Windows;
using System.Windows.Threading;
using Gyroball.Ble;
using Gyroball.Core;
using Gyroball.Core.Settings;
using Gyroball.Core.Storage;
using Gyroball.UI.Dashboard;
using Gyroball.UI.Tray;
using Gyroball.UI.Widget;
using Gyroball.ViewModels;

namespace Gyroball;

public partial class App : Application
{
    private const string MutexName = "Gyroball.SingleInstance.Mutex";
    private const string ReopenEventName = "Gyroball.SingleInstance.Reopen";

    private Mutex? _singleInstance;
    private EventWaitHandle? _reopenSignal;

    private LiveTelemetry _live = null!;
    private SessionStore _store = null!;
    private AppSettings _settings = null!;
    private AppViewModel _vm = null!;
    private BleManager _ble = null!;
    private SessionTracker _tracker = null!;
    private DispatcherTimer _timer = null!;

    private TrayIconController? _tray;
    private FloatingWidgetWindow? _widget;
    private DashboardWindow? _dashboard;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Single instance: a second launch just signals the running one to reopen.
        _singleInstance = new Mutex(initiallyOwned: true, MutexName, out bool isNew);
        if (!isNew)
        {
            try { EventWaitHandle.OpenExisting(ReopenEventName).Set(); } catch { /* ignore */ }
            Shutdown();
            return;
        }
        SetupReopenListener();

        // Core (platform-free) ---------------------------------------------------
        _live = new LiveTelemetry();
        _store = new SessionStore();
        _settings = AppSettings.Load();
        _vm = new AppViewModel(_live, _store);
        _tracker = new SessionTracker(_live, _store);
        _ble = new BleManager(_live, post: a => Dispatcher.Invoke(a));

        // Periodic heartbeat: flips idle after a quiet gap and closes finished sessions.
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += (_, _) =>
        {
            var now = DateTime.Now;
            _live.Tick(now);
            _tracker.CheckGrace(now);
        };
        _timer.Start();

        // UI ---------------------------------------------------------------------
        _tray = new TrayIconController(_vm,
            openDashboard: OpenDashboard,
            resetSession: () => _tracker.Discard(),
            quit: QuitApp);

        _widget = new FloatingWidgetWindow(_vm, _settings);

        _ble.Start();
        OpenDashboard();   // matches the macOS app opening the dashboard on launch
    }

    private void SetupReopenListener()
    {
        _reopenSignal = new EventWaitHandle(false, EventResetMode.AutoReset, ReopenEventName);
        ThreadPool.RegisterWaitForSingleObject(_reopenSignal,
            (_, _) => Dispatcher.BeginInvoke(OpenDashboard),
            null, Timeout.Infinite, executeOnlyOnce: false);
    }

    private void OpenDashboard()
    {
        if (_dashboard is null)
        {
            _dashboard = new DashboardWindow(_vm);
            _dashboard.Closed += (_, _) => _dashboard = null;
        }
        _dashboard.Show();
        if (_dashboard.WindowState == WindowState.Minimized)
            _dashboard.WindowState = WindowState.Normal;
        _dashboard.Activate();
    }

    private void QuitApp()
    {
        _tracker.FinalizeSession();   // persist the in-progress session (applicationWillTerminate)
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _timer?.Stop();
        _ble?.Dispose();
        _tray?.Dispose();
        _store?.Dispose();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }
}
