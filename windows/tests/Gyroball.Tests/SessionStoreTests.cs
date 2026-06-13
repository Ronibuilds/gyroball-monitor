using Gyroball.Core;
using Gyroball.Core.Storage;
using Xunit;

namespace Gyroball.Tests;

public class SessionStoreTests : IDisposable
{
    private readonly string _dbPath = Path.Combine(Path.GetTempPath(), $"gyro-store-{Guid.NewGuid():N}.sqlite");
    private readonly SessionStore _store;

    public SessionStoreTests() => _store = new SessionStore(_dbPath);

    private WorkoutSession Make(DateTime started, double revs = 1000, double topRpm = 5000,
                                double duration = 300, double[]? samples = null) => new()
    {
        StartedAt = started,
        Duration = duration,
        TopRpm = topRpm,
        AvgRpm = 4000,
        Revolutions = revs,
        Samples = samples ?? new[] { 4000.0, 5000.0 }
    };

    [Fact]
    public void Add_PersistsAndReloads_WithSamplesRoundTrip()
    {
        var samples = new[] { 3500.0, 4200.5, 5100.0 };
        _store.Add(Make(DateTime.Now, samples: samples));

        Assert.Single(_store.Sessions);
        Assert.Equal(samples, _store.Sessions[0].Samples);
        Assert.True(_store.Sessions[0].Id > 0);
    }

    [Fact]
    public void Sessions_OrderedNewestFirst()
    {
        var day1 = new DateTime(2026, 1, 1, 8, 0, 0);
        var day2 = new DateTime(2026, 1, 2, 8, 0, 0);
        _store.Add(Make(day1));
        _store.Add(Make(day2));
        Assert.Equal(day2, _store.Sessions[0].StartedAt);
        Assert.Equal(day1, _store.Sessions[1].StartedAt);
    }

    [Fact]
    public void Delete_RemovesSession()
    {
        _store.Add(Make(DateTime.Now));
        _store.Delete(_store.Sessions[0]);
        Assert.Empty(_store.Sessions);
    }

    [Fact]
    public void TodayAggregates_OnlyCountToday()
    {
        _store.Add(Make(DateTime.Now, revs: 500, duration: 120));
        _store.Add(Make(DateTime.Now, revs: 700, duration: 180));
        _store.Add(Make(DateTime.Today.AddDays(-3), revs: 9999, duration: 9999));

        Assert.Equal(1200, _store.TodayRevolutions);
        Assert.Equal(300, _store.TodaySeconds);
        Assert.Equal(2, _store.TodaySessionCount);
    }

    [Fact]
    public void AllTimeAggregates()
    {
        _store.Add(Make(DateTime.Now, revs: 500, topRpm: 5000, duration: 100));
        _store.Add(Make(DateTime.Now.AddHours(-2), revs: 800, topRpm: 7200, duration: 400));

        Assert.Equal(7200, _store.AllTimeTopRpm);
        Assert.Equal(1300, _store.TotalRevolutions);
        Assert.Equal(500, _store.TotalSeconds);
        Assert.Equal(400, _store.LongestSession!.Duration);
        Assert.Equal(7200, _store.BestSession!.TopRpm);
    }

    [Fact]
    public void DailyHistory_Has14ZeroFilledDays_OldestFirst()
    {
        _store.Add(Make(DateTime.Today, revs: 100));
        _store.Add(Make(DateTime.Today.AddDays(-2), revs: 250));

        var history = _store.DailyHistory();
        Assert.Equal(14, history.Count);
        Assert.True(history[0].Day < history[13].Day);    // oldest first
        Assert.Equal(DateTime.Today, history[13].Day);    // last entry is today
        Assert.Equal(100, history[13].Revs);
        Assert.Equal(250, history[11].Revs);              // two days ago
        Assert.Equal(0, history[12].Revs);                // zero-filled gap
    }

    [Fact]
    public void EmptyStore_AggregatesAreZero()
    {
        Assert.Equal(0, _store.AllTimeTopRpm);
        Assert.Equal(0, _store.TotalRevolutions);
        Assert.Null(_store.LongestSession);
        Assert.Null(_store.BestSession);
    }

    [Fact]
    public void Persistence_SurvivesReopen()
    {
        _store.Add(Make(DateTime.Now, revs: 1234));
        _store.Dispose();

        using var reopened = new SessionStore(_dbPath);
        Assert.Single(reopened.Sessions);
        Assert.Equal(1234, reopened.Sessions[0].Revolutions);
    }

    public void Dispose()
    {
        _store.Dispose();
        if (File.Exists(_dbPath)) File.Delete(_dbPath);
    }
}
