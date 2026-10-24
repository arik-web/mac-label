using Microsoft.Win32;

namespace MacLabel.Windows;

/// <summary>
/// The Windows lock screen, like macOS, shows no app window. Two layers:
///
/// Lock (signed in): the lock screen uses the desktop wallpaper, so the
/// label is baked, centered, into a copy of the current wallpaper and
/// swapped in on SessionLock, original restored on SessionUnlock.
///
/// Login (nobody signed in): the same baked image installed as the system
/// lock-screen image via PersonalizationCSP (HKLM, needs one UAC prompt).
/// </summary>
public static class LockImage
{
    public static string BakedPath => Path.Combine(Settings.DirectoryPath, "lock-wallpaper.jpg");
    public static string ProgramDataPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "MacLabel", "lock.jpg");

    private static string? _originalWallpaper;

    /// <summary>Bakes the centered label into a copy of the current desktop wallpaper.</summary>
    public static bool Bake(Settings settings)
    {
        var source = CurrentWallpaperPath();
        if (source == null || !File.Exists(source)) return false;
        try
        {
            using var image = Image.FromFile(source);
            var screen = Screen.PrimaryScreen!.Bounds;
            var scale = (double)image.Height / screen.Height;
            var fontSize = (float)(settings.EffectiveLockFontSize * scale);
            using var font = new Font("Segoe UI", fontSize, FontStyle.Bold);
            var textSize = TextRenderer.MeasureText(settings.DisplayName, font);
            var padding = new Size((int)(fontSize * 0.6), (int)(fontSize * 0.35));
            var box = new Size(textSize.Width + padding.Width * 2, textSize.Height + padding.Height * 2);

            using var canvas = new Bitmap(image);
            using (var g = Graphics.FromImage(canvas))
            {
                var origin = new Point((canvas.Width - box.Width) / 2, (canvas.Height - box.Height) / 2);
                using var brush = new SolidBrush(Color.FromArgb((int)(settings.BackgroundOpacity * 255), Color.Black));
                g.FillRectangle(brush, new Rectangle(origin, box));
                var (r, gg, b) = Settings.Rgb(settings.NormalizedColor);
                using var textBrush = new SolidBrush(Color.FromArgb(r, gg, b));
                g.DrawString(settings.DisplayName, font, textBrush, origin.X + padding.Width, origin.Y + padding.Height);
            }
            Directory.CreateDirectory(Settings.DirectoryPath);
            canvas.Save(BakedPath, System.Drawing.Imaging.ImageFormat.Jpeg);
            return true;
        }
        catch { return false; }
    }

    public static void OnLock(Settings settings)
    {
        if (!settings.LoginLockVisible || !Bake(settings)) return;
        _originalWallpaper = CurrentWallpaperPath();
        SetWallpaper(BakedPath);
    }

    public static void OnUnlock()
    {
        if (_originalWallpaper != null && File.Exists(_originalWallpaper))
            SetWallpaper(_originalWallpaper);
        _originalWallpaper = null;
    }

    /// <summary>
    /// Installs the baked image as the login-screen image (admin).
    /// Returns false when elevation was declined or the write failed.
    /// </summary>
    public static bool InstallLoginImage(Settings settings)
    {
        if (!Bake(settings)) return false;
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ProgramDataPath)!);
            File.Copy(BakedPath, ProgramDataPath, overwrite: true);
            using var key = Registry.LocalMachine.CreateSubKey(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP");
            key.SetValue("LockScreenImagePath", ProgramDataPath);
            key.SetValue("LockScreenImageUrl", ProgramDataPath);
            key.SetValue("LockScreenImageStatus", 1, RegistryValueKind.DWord);
            return true;
        }
        catch (UnauthorizedAccessException) { return false; }
    }

    public static void RemoveLoginImage()
    {
        try
        {
            Registry.LocalMachine.DeleteSubKeyTree(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP", throwOnMissingSubKey: false);
        }
        catch (UnauthorizedAccessException) { }
    }

    private static string? CurrentWallpaperPath()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop");
        return key?.GetValue("WallPaper") as string;
    }

    private static void SetWallpaper(string path)
    {
        SystemParametersInfo(0x0014, 0, path, 0x01 | 0x02);
    }

    [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
