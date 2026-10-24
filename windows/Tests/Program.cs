using MacLabel.Windows;

var failures = 0;
void Check(bool condition, string message)
{
    if (!condition) { failures++; Console.WriteLine($"FAIL: {message}"); }
}

// sanitize
Check(Settings.Sanitize("  Mini  ") == "Mini", "trims whitespace");
Check(Settings.Sanitize("   ") == null, "blank is null");
Check(Settings.Sanitize("") == null, "empty is null");
Check(Settings.Sanitize(new string('x', 100))!.Length == Settings.MaxNameLength, "caps length");

// display name
var s = new Settings();
Check(s.DisplayName == Settings.ComputerName, "defaults to computer name");
Check(!s.HasCustomName, "no custom name by default");
s.SetDisplayName("  PC (left)  ");
Check(s.DisplayName == "PC (left)", "custom name stored trimmed");
Check(s.HasCustomName, "custom name flagged");
s.SetDisplayName("");
Check(!s.HasCustomName, "empty resets to computer name");

// hex
Check(Settings.NormalizeHex("#ffcc00") == "FFCC00", "normalizes hex");
Check(Settings.NormalizeHex("FFF") == null, "rejects short hex");
Check(Settings.NormalizeHex("GGGGGG") == null, "rejects non-hex");
var rgb = Settings.Rgb("FF8000");
Check(rgb.Red == 255 && rgb.Blue == 0 && Math.Abs(rgb.Green - 128) < 1, "hex to rgb");
s.NormalizedColor = "nope";
Check(s.NormalizedColor == Settings.DefaultColorHex, "bad color ignored");
s.NormalizedColor = "#00ff00";
Check(s.NormalizedColor == "00FF00", "color stored");

// lock size: 0 = same as on-screen
Check(s.LockFontSize == 0 && s.EffectiveLockFontSize == s.FontSize, "lock size follows screen by default");
s.FontSize = 32;
Check(s.EffectiveLockFontSize == 32, "lock size follows screen change");
s.LockFontSize = 48;
Check(s.EffectiveLockFontSize == 48, "chosen lock size wins");
s.LockFontSize = 0;
Check(s.EffectiveLockFontSize == 32, "reset lock size follows screen again");
Check(Settings.ClampSize(999) == Settings.FontSizeRange.Max, "size clamped high");
Check(Settings.ClampOpacity(-1) == 0, "opacity clamped low");

Console.WriteLine(failures == 0 ? "OK all tests passed" : $"{failures} failure(s)");
return failures == 0 ? 0 : 1;
