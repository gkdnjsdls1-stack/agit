# Draws the home-screen icon (the gem, on the game's cream) and writes the sizes
# a phone asks for. Re-run after changing the palette.
#
#   .\tools\make-icons.ps1
#
# ASCII only on purpose: Windows PowerShell 5.1 reads .ps1 as ANSI and non-ASCII
# inside the C# here-string corrupts the source.
param([string]$OutDir = (Split-Path $PSScriptRoot -Parent))

Add-Type -AssemblyName System.Drawing

$code = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class IconMaker
{
    // the gem as it is drawn in the page, in its 200x240 viewBox
    static readonly PointF[] Outline = {
        new PointF(100,8), new PointF(170,70), new PointF(148,212), new PointF(52,212), new PointF(30,70) };
    static readonly PointF[] Table = {
        new PointF(100,8), new PointF(170,70), new PointF(100,96), new PointF(30,70) };
    static readonly PointF[] Left = {
        new PointF(30,70), new PointF(100,96), new PointF(52,212) };
    static readonly PointF[] Right = {
        new PointF(170,70), new PointF(148,212), new PointF(100,96) };
    static readonly PointF[] Middle = {
        new PointF(100,96), new PointF(148,212), new PointF(52,212) };
    static readonly PointF[] Glint = {
        new PointF(62,62), new PointF(96,36), new PointF(104,44), new PointF(70,70) };

    static Color C(string hex)
    {
        return Color.FromArgb(
            Convert.ToInt32(hex.Substring(1, 2), 16),
            Convert.ToInt32(hex.Substring(3, 2), 16),
            Convert.ToInt32(hex.Substring(5, 2), 16));
    }

    static PointF[] Fit(PointF[] p, float scale, float dx, float dy)
    {
        PointF[] o = new PointF[p.Length];
        for (int i = 0; i < p.Length; i++) { o[i] = new PointF(p[i].X * scale + dx, p[i].Y * scale + dy); }
        return o;
    }

    public static void Write(string path, int size)
    {
        using (Bitmap bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(C("#fdf6e7"));

            // keep the gem inside the middle 80%, so a round or squircle mask
            // from the launcher never clips it
            float safe = size * .62f;
            float scale = safe / 240f;
            float dx = (size - 200f * scale) / 2f;
            float dy = (size - 240f * scale) / 2f;

            using (Brush table = new LinearGradientBrush(
                       new PointF(0, dy), new PointF(0, dy + 240 * scale), C("#d7a9f2"), C("#a86ad6")))
            using (Brush left = new SolidBrush(C("#7a4aa8")))
            using (Brush right = new SolidBrush(C("#c492e8")))
            using (Brush mid = new SolidBrush(C("#a86ad6")))
            using (Brush glint = new SolidBrush(C("#fdf3ff")))
            using (Pen ink = new Pen(C("#3a2a20"), Math.Max(3f, size * .035f)))
            {
                ink.LineJoin = LineJoin.Round;
                g.FillPolygon(table, Fit(Table, scale, dx, dy));
                g.FillPolygon(left, Fit(Left, scale, dx, dy));
                g.FillPolygon(right, Fit(Right, scale, dx, dy));
                g.FillPolygon(mid, Fit(Middle, scale, dx, dy));
                g.FillPolygon(glint, Fit(Glint, scale, dx, dy));
                g.DrawPolygon(ink, Fit(Outline, scale, dx, dy));
            }
            bmp.Save(path, ImageFormat.Png);
        }
    }
}
'@

if (-not ([System.Management.Automation.PSTypeName]'IconMaker').Type) {
  Add-Type -TypeDefinition $code -ReferencedAssemblies "System.Drawing" -ErrorAction Stop
}

$root = (Resolve-Path $OutDir).Path
foreach ($s in 180, 192, 512) {
  $p = Join-Path $root ("icon-" + $s + ".png")
  [IconMaker]::Write($p, $s)
  "wrote icon-$s.png"
}
