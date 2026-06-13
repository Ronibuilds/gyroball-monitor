using System.Text.Json;

namespace Gyroball.Core.Settings;

/// <summary>
/// Tiny JSON-backed settings store, replacing macOS UserDefaults. Persists the
/// floating widget's position and pin state to %APPDATA%\Gyroball\settings.json.
/// </summary>
public sealed class AppSettings
{
    /// <summary>Serializable payload — what actually lands in settings.json.</summary>
    private sealed class Data
    {
        public double? WidgetX { get; set; }
        public double? WidgetY { get; set; }
        public bool WidgetPinned { get; set; }
    }

    private readonly string _path;
    private Data _data;

    private AppSettings(string path, Data data)
    {
        _path = path;
        _data = data;
    }

    public double? WidgetX { get => _data.WidgetX; set => _data.WidgetX = value; }
    public double? WidgetY { get => _data.WidgetY; set => _data.WidgetY = value; }
    public bool WidgetPinned { get => _data.WidgetPinned; set => _data.WidgetPinned = value; }

    public static string DefaultPath()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Gyroball");
        Directory.CreateDirectory(dir);
        return Path.Combine(dir, "settings.json");
    }

    public static AppSettings Load(string? path = null)
    {
        path ??= DefaultPath();
        Data data;
        try
        {
            data = File.Exists(path)
                ? JsonSerializer.Deserialize<Data>(File.ReadAllText(path)) ?? new Data()
                : new Data();
        }
        catch
        {
            data = new Data();
        }
        return new AppSettings(path, data);
    }

    public void Save()
    {
        try
        {
            File.WriteAllText(_path, JsonSerializer.Serialize(_data,
                new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* best-effort */ }
    }
}
