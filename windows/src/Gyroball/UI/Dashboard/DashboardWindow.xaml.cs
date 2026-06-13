using System.Collections.Specialized;
using System.Windows;
using System.Windows.Controls;
using Gyroball.Core;
using Gyroball.ViewModels;

namespace Gyroball.UI.Dashboard;

/// <summary>
/// The main window: a sidebar (Overview + session list) and a detail host, mirroring
/// the macOS NavigationSplitView in DashboardView.swift.
/// </summary>
public partial class DashboardWindow : Window
{
    private readonly AppViewModel _vm;
    private readonly OverviewView _overview;

    public DashboardWindow(AppViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        DataContext = vm;

        _overview = new OverviewView { DataContext = vm };
        ShowOverview();

        UpdateEmptyHint();
        _vm.Store.Sessions.CollectionChanged += OnSessionsChanged;
    }

    private void OnSessionsChanged(object? sender, NotifyCollectionChangedEventArgs e) => UpdateEmptyHint();

    private void UpdateEmptyHint() =>
        EmptyHint.Visibility = _vm.Store.Sessions.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

    private void OnOverviewClick(object sender, RoutedEventArgs e)
    {
        SessionsList.SelectedItem = null;
        ShowOverview();
    }

    private void OnSessionSelected(object sender, SelectionChangedEventArgs e)
    {
        if (SessionsList.SelectedItem is WorkoutSession session)
            ShowDetail(session);
    }

    private void ShowOverview() => ContentHost.Content = _overview;

    private void ShowDetail(WorkoutSession session)
    {
        ContentHost.Content = new SessionDetailView(session, _vm.Store, onDelete: () =>
        {
            SessionsList.SelectedItem = null;
            ShowOverview();
        });
    }

    protected override void OnClosed(EventArgs e)
    {
        _vm.Store.Sessions.CollectionChanged -= OnSessionsChanged;
        base.OnClosed(e);
    }
}
