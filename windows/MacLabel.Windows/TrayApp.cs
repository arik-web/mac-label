using System.Diagnostics;
using Microsoft.Win32;

namespace MacLabel.Windows;

/// <summary>Tray icon, context menu, and glue. The Windows twin of AppDelegate.</summary>
public sealed class TrayApp : ApplicationContext
{
    private static readonly (string Name, string Hex)[] Colors =
    {
        ("White", "FFFFFF"), ("Yellow", "FFD60A"), ("Orange", "FF9F0A"), ("Red", "FF453A"),
        ("Pink", "FF375F"), ("Purple", "BF5AF2"), ("Blue", "0A84FF"), ("Cyan", "64D2FF"),
        ("Green", "30D158"), ("Black", "000000"),
    };
    private static readonly (string Name, double Size)[] Sizes =
    {
        ("Small", 16), ("Medium", 22), ("Large", 32), ("Extra large", 48), ("Huge", 72),
    };
    private static readonly double[] Opacities = { 0, 0.2, 0.4, 0.6, 0.8, 1 };

    private readonly Settings _settings = Settings.Load();
    private readonly Overlay _overlay = new();
    private readonly NotifyIcon _tray;
    private Icon? _icon;

    private readonly ToolStripMenuItem _overlayItem = new("Show name on screen");
    private readonly ToolStripMenuItem _loginLockItem = new("Show on login && lock screens");
    private readonly ToolStripMenuItem _startupItem = new("Launch at startup");
    private readonly ToolStripMenuItem _resetItem = new("Reset to computer name");

    public TrayApp()
    {
        var menu = new ContextMenuStrip();
        var header = new ToolStripMenuItem { Enabled = false };
        header.Name = "header";
        menu.Items.Add(header);
        menu.Items.Add(_overlayItem);
        menu.Items.Add(_loginLockItem);
        menu.Items.Add(new ToolStripSeparator());

        var editItem = new ToolStripMenuItem("Edit name…");
        editItem.Click += (_, _) => EditName();
        menu.Items.Add(editItem);
        menu.Items.Add(_resetItem);
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(Submenu("Text color", ColorItems()));
        menu.Items.Add(Submenu("Text size", SizeItems(_settings.FontSize, size =>
        {
            _settings.FontSize = size; SaveAndRefresh();
        })));
        menu.Items.Add(Submenu("Background", OpacityItems()));
        menu.Items.Add(Submenu("Lock screen size", LockSizeItems()));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(_startupItem);
        var quitItem = new ToolStripMenuItem("Quit Mac Label");
        quitItem.Click += (_, _) => Exit();
        menu.Items.Add(quitItem);

        _overlayItem.Click += (_, _) => { _settings.OverlayVisible = !_settings.OverlayVisible; SaveAndRefresh(); };
        _loginLockItem.Click += (_, _) => ToggleLoginLock();
        _startupItem.Click += (_, _) => ToggleStartup();
        _resetItem.Click += (_, _) => { _settings.SetDisplayName(""); SaveAndRefresh(); };
        menu.Opening += (_, _) => RefreshChecks(menu);

        _tray = new NotifyIcon
        {
            ContextMenuStrip = menu,
            Visible = true,
        };

        SystemEvents.SessionSwitch += OnSessionSwitch;
        SystemEvents.DisplaySettingsChanged += (_, _) => Refresh();
        Refresh();
    }

    private static ToolStripMenuItem Submenu(string title, IEnumerable<ToolStripMenuItem> items)
    {
        var menu = new ToolStripMenuItem(title);
        foreach (var item in items) menu.DropDownItems.Add(item);
        return menu;
    }

    private Color LabelColor
    {
        get
        {
            var (r, g, b) = Settings.Rgb(_settings.NormalizedColor);
            return Color.FromArgb(r, g, b);
        }
    }

    private void Refresh()
    {
        var name = _settings.DisplayName;
        _tray.Text = name.Length > 63 ? name[..63] : name;
        if (_tray.ContextMenuStrip?.Items["header"] is ToolStripMenuItem header) header.Text = name;
        _icon?.Dispose();
        _icon = MakeIcon(name);
        _tray.Icon = _icon;
        if (_settings.OverlayVisible)
            _overlay.Show(name, LabelColor, (float)_settings.FontSize, _settings.BackgroundOpacity);
        else
            _overlay.Hide();
        if (_settings.LoginLockVisible) LockImage.Bake(_settings);
    }

    private void RefreshChecks(ContextMenuStrip menu)
    {
        _overlayItem.Checked = _settings.OverlayVisible;
        _loginLockItem.Checked = _settings.LoginLockVisible;
        _startupItem.Checked = IsStartupEnabled();
        _resetItem.Enabled = _settings.HasCustomName;
        if (menu.Items["header"] is ToolStripMenuItem header) header.Text = _settings.DisplayName;
    }

    private void SaveAndRefresh()
    {
        _settings.Save();
        Refresh();
    }

    private void EditName()
    {
        using var form = new Form
        {
            Text = "Name for this PC",
            FormBorderStyle = FormBorderStyle.FixedDialog,
            StartPosition = FormStartPosition.CenterScreen,
            ClientSize = new Size(320, 110),
            MaximizeBox = false,
            MinimizeBox = false,
        };
        var box = new TextBox { Text = _settings.DisplayName, Location = new Point(12, 12), Width = 296 };
        var hint = new Label
        {
            Text = "Leave empty to use the computer name.",
            Location = new Point(12, 42), AutoSize = true,
        };
        var ok = new Button { Text = "Save", DialogResult = DialogResult.OK, Location = new Point(150, 72) };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Location = new Point(233, 72) };
        form.Controls.AddRange(new Control[] { box, hint, ok, cancel });
        form.AcceptButton = ok;
        form.CancelButton = cancel;
        if (form.ShowDialog() != DialogResult.OK) return;
        _settings.SetDisplayName(box.Text);
        SaveAndRefresh();
    }

    private IEnumerable<ToolStripMenuItem> ColorItems()
    {
        foreach (var (name, hex) in Colors)
        {
            var item = new ToolStripMenuItem(name) { Tag = hex, Checked = hex == _settings.NormalizedColor };
            item.Click += (_, _) => { _settings.NormalizedColor = hex; SaveAndRefresh(); };
            yield return item;
        }
        var custom = new ToolStripMenuItem("Custom…");
        custom.Click += (_, _) =>
        {
            using var dialog = new ColorDialog { Color = LabelColor };
            if (dialog.ShowDialog() != DialogResult.OK) return;
            _settings.NormalizedColor = $"{dialog.Color.R:X2}{dialog.Color.G:X2}{dialog.Color.B:X2}";
            SaveAndRefresh();
        };
        yield return custom;
    }

    private static IEnumerable<ToolStripMenuItem> SizeItems(double current, Action<double> pick)
    {
        foreach (var (name, size) in Sizes)
        {
            var item = new ToolStripMenuItem($"{name} ({(int)size} pt)") { Tag = size, Checked = size == current };
            item.Click += (_, _) => pick(size);
            yield return item;
        }
    }

    private IEnumerable<ToolStripMenuItem> OpacityItems()
    {
        foreach (var opacity in Opacities)
        {
            var item = new ToolStripMenuItem(opacity == 0 ? "None (text only)" : $"{(int)(opacity * 100)}% dark")
            {
                Tag = opacity,
                Checked = Math.Abs(opacity - _settings.BackgroundOpacity) < 0.01,
            };
            item.Click += (_, _) => { _settings.BackgroundOpacity = opacity; SaveAndRefresh(); };
            yield return item;
        }
    }

    private IEnumerable<ToolStripMenuItem> LockSizeItems()
    {
        var same = new ToolStripMenuItem("Same as on-screen") { Tag = 0.0, Checked = _settings.LockFontSize == 0 };
        same.Click += (_, _) => { _settings.LockFontSize = 0; SaveAndRefresh(); };
        yield return same;
        foreach (var item in SizeItems(_settings.LockFontSize, size =>
        {
            _settings.LockFontSize = size; SaveAndRefresh();
        })) yield return item;
    }

    private void ToggleLoginLock()
    {
        if (_settings.LoginLockVisible)
        {
            LockImage.OnUnlock();
            LockImage.RemoveLoginImage();
            _settings.LoginLockVisible = false;
        }
        else
        {
            _settings.LoginLockVisible = true;
            if (!LockImage.InstallLoginImage(_settings))
            {
                // Needs admin: relaunch elevated to write the HKLM keys.
                try
                {
                    var start = new ProcessStartInfo(Application.ExecutablePath, "--install-lock")
                    {
                        Verb = "runas",
                        UseShellExecute = true,
                    };
                    Process.Start(start)?.WaitForExit();
                }
                catch { /* user declined UAC: lock swap still works, login image not set */ }
            }
        }
        SaveAndRefresh();
    }

    // MARK: Launch at startup (HKCU Run)

    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    private static bool IsStartupEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue("MacLabel") is string;
    }

    private void ToggleStartup()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (IsStartupEnabled()) key.DeleteValue("MacLabel", throwOnMissingValue: false);
        else key.SetValue("MacLabel", $"\"{Application.ExecutablePath}\"");
    }

    private void OnSessionSwitch(object sender, SessionSwitchEventArgs e)
    {
        switch (e.Reason)
        {
            case SessionSwitchReason.SessionLock: LockImage.OnLock(_settings); break;
            case SessionSwitchReason.SessionUnlock: LockImage.OnUnlock(); break;
        }
    }

    /// <summary>Draws the name (shrunk to fit) as the tray icon.</summary>
    private Icon MakeIcon(string name)
    {
        using var bitmap = new Bitmap(64, 64);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.Clear(Color.Transparent);
            var size = 40f;
            Font font;
            do
            {
                font = new Font("Segoe UI", size, FontStyle.Bold);
                size -= 4;
            } while (TextRenderer.MeasureText(name, font).Width > 60 && size > 8);
            using (font)
            using (var brush = new SolidBrush(LabelColor))
            {
                var rect = new RectangleF(0, 0, 64, 64);
                using var format = new StringFormat
                {
                    Alignment = StringAlignment.Center,
                    LineAlignment = StringAlignment.Center,
                };
                g.DrawString(name, font, brush, rect, format);
            }
        }
        return Icon.FromHandle(bitmap.GetHicon());
    }

    private void Exit()
    {
        SystemEvents.SessionSwitch -= OnSessionSwitch;
        _overlay.Hide();
        _tray.Visible = false;
        _tray.Dispose();
        _icon?.Dispose();
        Application.Exit();
    }
}
