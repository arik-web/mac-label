namespace MacLabel.Windows;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        // Elevated helper: writes the HKLM login-screen image keys, then exits.
        if (args.Contains("--install-lock"))
        {
            return LockImage.InstallLoginImage(Settings.Load()) ? 0 : 1;
        }

        using var mutex = new Mutex(true, "MacLabel.Windows.SingleInstance", out var first);
        if (!first) return 0;

        ApplicationConfiguration.Initialize();
        Application.Run(new TrayApp());
        return 0;
    }
}
