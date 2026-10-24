using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace MacLabel.Windows;

/// <summary>
/// One borderless, click-through label per monitor, top-left of the working
/// area, always on top. Per-pixel alpha (UpdateLayeredWindow) so the dark
/// box can be translucent while the text stays solid. The Windows twin of
/// the macOS overlay window.
/// </summary>
public sealed class OverlayForm : Form
{
    private const int WsExTransparent = 0x20;
    private const int WsExLayered = 0x80000;
    private const int WsExNoActivate = 0x8000000;
    private const int WsExToolWindow = 0x80;

    private readonly string _text;
    private readonly Color _color;
    private readonly float _fontSize;
    private readonly double _backgroundOpacity;

    public OverlayForm(string text, Color color, float fontSize, double backgroundOpacity, Screen screen)
    {
        _text = text;
        _color = color;
        _fontSize = fontSize;
        _backgroundOpacity = backgroundOpacity;

        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;

        using var font = LabelFont();
        var textSize = TextRenderer.MeasureText(text, font);
        var padding = new Size((int)(fontSize * 0.6), (int)(fontSize * 0.35));
        ClientSize = new Size(textSize.Width + padding.Width * 2, textSize.Height + padding.Height * 2);
        var area = screen.WorkingArea;
        Location = new Point(area.Left + 12, area.Top + 12);
    }

    private Font LabelFont() => new("Segoe UI", _fontSize, FontStyle.Bold);

    protected override CreateParams CreateParams
    {
        get
        {
            var cp = base.CreateParams;
            cp.ExStyle |= WsExTransparent | WsExLayered | WsExNoActivate | WsExToolWindow;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation => true;

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        RenderLayered();
    }

    private void RenderLayered()
    {
        using var font = LabelFont();
        var padding = new Point((int)(_fontSize * 0.6), (int)(_fontSize * 0.35));
        using var bitmap = new Bitmap(ClientSize.Width, ClientSize.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.Clear(Color.Transparent);
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
            using var box = new SolidBrush(Color.FromArgb((int)(_backgroundOpacity * 255), Color.Black));
            using var path = RoundedRect(ClientRectangle, _fontSize * 0.45f);
            g.FillPath(box, path);
            using var textBrush = new SolidBrush(_color);
            g.DrawString(_text, font, textBrush, padding.X, padding.Y);
        }

        var screenDc = GetDC(IntPtr.Zero);
        var memDc = CreateCompatibleDC(screenDc);
        var hBitmap = bitmap.GetHbitmap(Color.FromArgb(0));
        var old = SelectObject(memDc, hBitmap);
        try
        {
            var size = new Size(bitmap.Width, bitmap.Height);
            var source = new Point(0, 0);
            var top = Location;
            var blend = new BlendFunction
            {
                BlendOp = 0, BlendFlags = 0, SourceConstantAlpha = 255, AlphaFormat = 1,
            };
            UpdateLayeredWindow(Handle, screenDc, ref top, ref size, memDc, ref source, 0, ref blend, 2);
        }
        finally
        {
            SelectObject(memDc, old);
            DeleteObject(hBitmap);
            DeleteDC(memDc);
            ReleaseDC(IntPtr.Zero, screenDc);
        }
    }

    private static System.Drawing.Drawing2D.GraphicsPath RoundedRect(Rectangle bounds, float radius)
    {
        var path = new System.Drawing.Drawing2D.GraphicsPath();
        var d = radius * 2;
        path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
        path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
        path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct BlendFunction
    {
        public byte BlendOp, BlendFlags, SourceConstantAlpha, AlphaFormat;
    }

    [DllImport("user32.dll")] private static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref Point pptDst, ref Size psize, IntPtr hdcSrc, ref Point pptSrc, int crKey, ref BlendFunction pblend, int dwFlags);
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("gdi32.dll")] private static extern IntPtr CreateCompatibleDC(IntPtr hDC);
    [DllImport("gdi32.dll")] private static extern bool DeleteDC(IntPtr hDC);
    [DllImport("gdi32.dll")] private static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObject);
    [DllImport("gdi32.dll")] private static extern bool DeleteObject(IntPtr hObject);
}

/// <summary>Owns one overlay form per monitor; recreates them on refresh.</summary>
public sealed class Overlay
{
    private readonly List<OverlayForm> _forms = new();

    public void Show(string text, Color color, float fontSize, double backgroundOpacity)
    {
        Hide();
        foreach (var screen in Screen.AllScreens)
        {
            var form = new OverlayForm(text, color, fontSize, backgroundOpacity, screen);
            _forms.Add(form);
            form.Show();
        }
    }

    public void Hide()
    {
        foreach (var form in _forms) { form.Close(); form.Dispose(); }
        _forms.Clear();
    }
}
