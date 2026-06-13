using System.ComponentModel;
using CommunityToolkit.Mvvm.ComponentModel;
using Gyroball.Core;
using Gyroball.Core.Storage;

namespace Gyroball.ViewModels;

/// <summary>
/// The binding hub for every view. Wraps the platform-free <see cref="LiveTelemetry"/>
/// and <see cref="SessionStore"/> and exposes the combined "today + current session"
/// values that the SwiftUI views computed inline. Re-raises change notifications when
/// either source updates so the UI stays live.
/// </summary>
public sealed class AppViewModel : ObservableObject
{
    public LiveTelemetry Live { get; }
    public SessionStore Store { get; }

    public AppViewModel(LiveTelemetry live, SessionStore store)
    {
        Live = live;
        Store = store;
        Live.PropertyChanged += OnLiveChanged;
        Store.PropertyChanged += (_, _) => RaiseCombined();
    }

    private void OnLiveChanged(object? sender, PropertyChangedEventArgs e) => RaiseCombined();

    // MARK: - Status (mirrors MenuContent / OverviewView header)

    public bool IsConnected => Live.IsConnected;
    public bool IsActive => Live.IsActive;

    public string StatusText => Live.IsConnected
        ? (Live.IsActive ? "Spinning" : "Connected — idle")
        : "Scanning for NSD Workout…";

    /// <summary>0 = disconnected (gray), 1 = idle (yellow), 2 = spinning (green).</summary>
    public int StatusLevel => Live.IsConnected ? (Live.IsActive ? 2 : 1) : 0;

    // MARK: - Combined today / all-time (store totals + the in-progress session)

    public double TodayRevolutionsCombined => Store.TodayRevolutions + Live.TotalRevolutions;
    public double TodaySecondsCombined => Store.TodaySeconds + Live.ActiveSeconds;
    public double AllTimeTopRpmCombined => Math.Max(Store.AllTimeTopRpm, Live.TopSpeed);

    /// <summary>Reference max for the widget's progress bar: all-time best with a sane floor.</summary>
    public double ReferenceMax => Math.Max(Math.Max(Store.AllTimeTopRpm, Live.TopSpeed), 6000);

    /// <summary>True when the current session has beaten the stored all-time top RPM.</summary>
    public bool IsNewBest => Store.AllTimeTopRpm > 0 && Live.TopSpeed > Store.AllTimeTopRpm;

    private void RaiseCombined()
    {
        foreach (var name in new[]
        {
            nameof(IsConnected), nameof(IsActive), nameof(StatusText), nameof(StatusLevel),
            nameof(TodayRevolutionsCombined), nameof(TodaySecondsCombined),
            nameof(AllTimeTopRpmCombined), nameof(ReferenceMax), nameof(IsNewBest)
        })
        {
            OnPropertyChanged(name);
        }
    }
}
