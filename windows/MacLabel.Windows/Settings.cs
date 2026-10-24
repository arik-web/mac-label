using System.Text.Json;

namespace MacLabel.Windows;

/// <summary>
/// Persisted user choices in %AppData%\MacLabel\settings.json, so each PC
/// keeps its own label. Pure logic only (no WinForms) so tests can link it.
/// </summary>
public sealed class Settings
{
    public const int MaxNameLength = 40;
    public const string DefaultColorHex = "FFFFFF";
    public const double DefaultFontSize = 22;
    public const double DefaultOpacity = 0.6;
    public static readonly (double Min, double Max) FontSizeRange = (10, 120);

    public string? CustomName { get; set; }
    public bool OverlayVisible { get; set; }
    public bool LoginLockVisible { get; set; }
    public string TextColorHex { get; set; } = DefaultColorHex;
    public double FontSize { get; set; } = DefaultFontSize;
    public double BackgroundOpacity { get; set; } = DefaultOpacity;

    /// <summary>0 (default) = same size as the on-screen label.</summary>
    public double LockFontSize { get; set; }

    public static string ComputerName =>
        Environment.GetEnvironmentVariable("COMPUTERNAME") ?? Environment.MachineName;

    /// <summary>Trims whitespace and caps length. Null for empty = use computer name.</summary>
    public static string? Sanitize(string? raw)
    {
        var trimmed = raw?.Trim();
        if (string.IsNullOrEmpty(trimmed)) return null;
        return trimmed.Length <= MaxNameLength ? trimmed : trimmed[..MaxNameLength];
    }

    public string DisplayName => Sanitize(CustomName) ?? ComputerName;
    public bool HasCustomName => Sanitize(CustomName) != null;

    public void SetDisplayName(string raw) => CustomName = Sanitize(raw);

    public double EffectiveLockFontSize => LockFontSize == 0 ? FontSize : ClampSize(LockFontSize);

    public static double ClampSize(double size) =>
        Math.Min(Math.Max(size, FontSizeRange.Min), FontSizeRange.Max);

    public static double ClampOpacity(double opacity) => Math.Min(Math.Max(opacity, 0), 1);

    /// <summary>"#ffcc00" / "FFCC00" to "FFCC00"; null when not six hex digits.</summary>
    public static string? NormalizeHex(string? raw)
    {
        var hex = raw?.Trim().Replace("#", "").ToUpperInvariant();
        if (hex is { Length: 6 } && hex.All(Uri.IsHexDigit)) return hex;
        return null;
    }

    public static (int Red, int Green, int Blue) Rgb(string? hex)
    {
        var value = Convert.ToUInt32(NormalizeHex(hex) ?? DefaultColorHex, 16);
        return ((int)(value >> 16) & 0xFF, (int)(value >> 8) & 0xFF, (int)value & 0xFF);
    }

    public string NormalizedColor
    {
        get => NormalizeHex(TextColorHex) ?? DefaultColorHex;
        set { if (NormalizeHex(value) is { } hex) TextColorHex = hex; }
    }

    // MARK: Persistence

    public static string DirectoryPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MacLabel");

    public static string FilePath => Path.Combine(DirectoryPath, "settings.json");

    public static Settings Load()
    {
        try
        {
            var settings = JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings();
            settings.TextColorHex = settings.NormalizedColor;
            settings.FontSize = ClampSize(settings.FontSize);
            settings.BackgroundOpacity = ClampOpacity(settings.BackgroundOpacity);
            if (settings.LockFontSize != 0) settings.LockFontSize = ClampSize(settings.LockFontSize);
            return settings;
        }
        catch { return new Settings(); }
    }

    public void Save()
    {
        Directory.CreateDirectory(DirectoryPath);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }
}
