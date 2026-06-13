using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using Gyroball.Core;
using Gyroball.ViewModels;
using H.NotifyIcon;
using H.NotifyIcon.Core;

namespace Gyroball.UI.Tray;

/// <summary>
/// System-tray icon and context menu — the Windows counterpart of the macOS
/// MenuBarExtra / MenuContent. The menu is rebuilt each time it opens so the live
/// stats reflect the current spin.
/// </summary>
public sealed class TrayIconController : IDisposable
{
    private readonly TaskbarIcon _icon;
    private readonly AppViewModel _vm;
    private readonly Action _openDashboard;
    private readonly Action _resetSession;
    private readonly Action _quit;

    public TrayIconController(AppViewModel vm, Action openDashboard, Action resetSession, Action quit)
    {
        _vm = vm;
        _openDashboard = openDashboard;
        _resetSession = resetSession;
        _quit = quit;

        _icon = new TaskbarIcon
        {
            IconSource = new BitmapImage(new Uri("pack://application:,,,/Assets/Gyroball.ico")),
            ToolTipText = "Gyroball",
            ContextMenu = new ContextMenu(),
            MenuActivation = PopupActivationMode.RightClick
        };
        _icon.TrayLeftMouseUp += (_, _) => _openDashboard();
        _icon.ContextMenu.Opened += (_, _) => BuildMenu();
        _icon.ForceCreate();

        _vm.PropertyChanged += (_, _) => _icon.ToolTipText = $"Gyroball — {_vm.StatusText}";
    }

    private void BuildMenu()
    {
        var menu = _icon.ContextMenu!;
        menu.Items.Clear();

        menu.Items.Add(Disabled(_vm.StatusText));
        menu.Items.Add(new Separator());
        menu.Items.Add(Action_("Open Dashboard…", _openDashboard));
        menu.Items.Add(new Separator());

        var live = _vm.Live;
        if (live.IsConnected)
        {
            menu.Items.Add(Disabled($"Current  {Fmt.Rpm(live.Rpm)} rpm"));
            menu.Items.Add(Disabled($"Top  {Fmt.Rpm(live.TopSpeed)} rpm"));
            menu.Items.Add(Disabled($"Average  {Fmt.Rpm(live.AverageRpm)} rpm"));
            menu.Items.Add(Disabled($"Revolutions  {Fmt.Revs(live.TotalRevolutions)}"));
            menu.Items.Add(Disabled($"Active time  {Fmt.Time(live.ActiveSeconds)}"));
            menu.Items.Add(new Separator());
        }

        menu.Items.Add(Disabled(
            $"Today  {Fmt.Revs(_vm.TodayRevolutionsCombined)} revs · {Fmt.Time(_vm.TodaySecondsCombined)}"));

        if (live.LastRawValue > 0)
        {
            var rpm = Telemetry.RpmFromRaw(live.LastRawValue) ?? 0;
            menu.Items.Add(Disabled($"Raw {live.LastRawValue} → {Fmt.Rpm(rpm)} rpm"));
        }

        menu.Items.Add(new Separator());
        if (live.IsConnected)
            menu.Items.Add(Action_("Reset session", _resetSession));
        menu.Items.Add(Action_("Quit Gyroball", _quit));
    }

    private static MenuItem Disabled(string header) => new() { Header = header, IsEnabled = false };

    private static MenuItem Action_(string header, Action onClick)
    {
        var item = new MenuItem { Header = header };
        item.Click += (_, _) => onClick();
        return item;
    }

    public void Dispose() => _icon.Dispose();
}
