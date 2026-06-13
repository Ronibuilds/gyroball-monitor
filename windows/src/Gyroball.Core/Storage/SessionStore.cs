using System.Collections.ObjectModel;
using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.Data.Sqlite;

namespace Gyroball.Core.Storage;

/// <summary>
/// SQLite-backed store for workout sessions plus the aggregates the UI shows.
/// Schema is identical to the macOS app's SessionStore.swift, so the two ports
/// read the same database shape. Observable for WPF binding.
/// </summary>
public sealed class SessionStore : ObservableObject, IDisposable
{
    private readonly Database _db;

    public ObservableCollection<WorkoutSession> Sessions { get; } = new();

    /// <summary>Default location: %APPDATA%\Gyroball\gyroball.sqlite (parallels ~/Library/Application Support).</summary>
    public static string DefaultPath()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Gyroball");
        Directory.CreateDirectory(dir);
        return Path.Combine(dir, "gyroball.sqlite");
    }

    public SessionStore(string? path = null)
    {
        _db = new Database(path ?? DefaultPath());
        _db.Run("""
            CREATE TABLE IF NOT EXISTS sessions(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at REAL NOT NULL,
                duration REAL NOT NULL,
                top_rpm REAL NOT NULL,
                avg_rpm REAL NOT NULL,
                revolutions REAL NOT NULL,
                samples TEXT NOT NULL DEFAULT '[]'
            )
            """);
        _db.Run("CREATE INDEX IF NOT EXISTS idx_sessions_started ON sessions(started_at)");
        Reload();
    }

    // MARK: - CRUD

    public void Add(WorkoutSession session)
    {
        var samplesJson = JsonSerializer.Serialize(session.Samples);
        _db.Run("""
            INSERT INTO sessions (started_at, duration, top_rpm, avg_rpm, revolutions, samples)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            new object[]
            {
                ToUnix(session.StartedAt),
                session.Duration,
                session.TopRpm,
                session.AvgRpm,
                session.Revolutions,
                samplesJson
            });
        Reload();
    }

    public void Delete(WorkoutSession session)
    {
        _db.Run("DELETE FROM sessions WHERE id = ?", new object[] { session.Id });
        Reload();
    }

    private void Reload()
    {
        var loaded = new List<WorkoutSession>();
        _db.Run("""
            SELECT id, started_at, duration, top_rpm, avg_rpm, revolutions, samples
            FROM sessions ORDER BY started_at DESC
            """, row: r =>
        {
            double[] samples;
            try { samples = JsonSerializer.Deserialize<double[]>(r.GetString(6)) ?? Array.Empty<double>(); }
            catch { samples = Array.Empty<double>(); }

            loaded.Add(new WorkoutSession
            {
                Id = r.GetInt64(0),
                StartedAt = FromUnix(r.GetDouble(1)),
                Duration = r.GetDouble(2),
                TopRpm = r.GetDouble(3),
                AvgRpm = r.GetDouble(4),
                Revolutions = r.GetDouble(5),
                Samples = samples
            });
        });

        Sessions.Clear();
        foreach (var s in loaded) Sessions.Add(s);
        RaiseAggregatesChanged();
    }

    // MARK: - Aggregates

    public IEnumerable<WorkoutSession> TodaySessions =>
        Sessions.Where(s => s.StartedAt.Date == DateTime.Today);

    public double TodayRevolutions => TodaySessions.Sum(s => s.Revolutions);
    public double TodaySeconds => TodaySessions.Sum(s => s.Duration);
    public int TodaySessionCount => TodaySessions.Count();

    public double AllTimeTopRpm => Sessions.Count == 0 ? 0 : Sessions.Max(s => s.TopRpm);
    public double TotalRevolutions => Sessions.Sum(s => s.Revolutions);
    public double TotalSeconds => Sessions.Sum(s => s.Duration);
    public WorkoutSession? LongestSession => Sessions.MaxBy(s => s.Duration);
    public WorkoutSession? BestSession => Sessions.MaxBy(s => s.TopRpm);

    /// <summary>Revolutions per day for the last 14 days, oldest first, zero-filled.</summary>
    public IReadOnlyList<(DateTime Day, double Revs)> DailyHistory()
    {
        var today = DateTime.Today;
        var byDay = new Dictionary<DateTime, double>();
        foreach (var s in Sessions)
        {
            var day = s.StartedAt.Date;
            byDay[day] = byDay.GetValueOrDefault(day) + s.Revolutions;
        }

        var result = new List<(DateTime, double)>(14);
        for (int offset = 13; offset >= 0; offset--)
        {
            var day = today.AddDays(-offset);
            result.Add((day, byDay.GetValueOrDefault(day)));
        }
        return result;
    }

    private void RaiseAggregatesChanged()
    {
        foreach (var name in new[]
        {
            nameof(TodayRevolutions), nameof(TodaySeconds), nameof(TodaySessionCount),
            nameof(AllTimeTopRpm), nameof(TotalRevolutions), nameof(TotalSeconds),
            nameof(LongestSession), nameof(BestSession)
        })
        {
            OnPropertyChanged(name);
        }
    }

    private static double ToUnix(DateTime dt) =>
        new DateTimeOffset(dt.ToUniversalTime()).ToUnixTimeMilliseconds() / 1000.0;

    private static DateTime FromUnix(double seconds) =>
        DateTimeOffset.FromUnixTimeMilliseconds((long)(seconds * 1000)).LocalDateTime;

    public void Dispose() => _db.Dispose();
}
