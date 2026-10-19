# Keys out the flat magenta background and cuts a horizontal row of sprites
# into individual transparent PNGs.
#
#   .\cut-sprites.ps1 -In ..\art\sheet-b.png -OutDir ..\art\sprites -Prefix char
#
# ASCII only on purpose: Windows PowerShell 5.1 reads .ps1 as ANSI and
# non-ASCII comments inside the C# here-string corrupt the source.
param(
  [Parameter(Mandatory=$true)][string]$In,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [Parameter(Mandatory=$true)][string]$Prefix,
  [int]$MinGap = 8,
  [int]$MinWidth = 30,
  [int]$Pad = 6,
  [int]$MinCol = 4,
  [int]$Inset = 0,
  [switch]$Profile
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SpriteCutter
{
    // "magenta-ness" = min(R,B) - G. Magenta has G far below both R and B.
    // Palette colours survive: coral pink scores ~0, lilac ~30.
    const int FullKey = 95;   // at or above this -> fully transparent
    const int NoKey   = 45;   // at or below this -> fully opaque

    public static int[] Profile(string inPath)
    {
        int w, h, stride;
        byte[] px;
        Bitmap src = Load(inPath, out w, out h, out stride, out px);
        src.Dispose();
        int[] colCount = new int[w];
        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
                if (px[row + x * 4 + 3] > 40) colCount[x]++;
        }
        return colCount;
    }

    // Neighbouring sprites touch, so a crop can carry a slice of the sprite next
    // door. Those slices always run off the left or right edge of the crop, so:
    // keep the biggest blob, plus any blob that stays clear of both side edges.
    static void DropEdgeFragments(Bitmap bmp)
    {
        int w = bmp.Width, h = bmp.Height;
        Rectangle all = new Rectangle(0, 0, w, h);
        BitmapData bd = bmp.LockBits(all, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = bd.Stride;
        byte[] px = new byte[stride * h];
        Marshal.Copy(bd.Scan0, px, 0, px.Length);

        int[] label = new int[w * h];
        int[] stack = new int[w * h];
        List<int> size = new List<int>();
        List<bool> touchesSide = new List<bool>();
        size.Add(0); touchesSide.Add(true);           // index 0 is "unlabelled"
        int cur = 0, best = 0, bestSize = 0;

        for (int y0 = 0; y0 < h; y0++)
        for (int x0 = 0; x0 < w; x0++)
        {
            int id0 = y0 * w + x0;
            if (label[id0] != 0 || px[y0 * stride + x0 * 4 + 3] <= 170) continue;

            cur++;
            int sp = 0, n = 0;
            bool side = false;
            stack[sp++] = id0; label[id0] = cur;
            while (sp > 0)
            {
                int p = stack[--sp]; n++;
                int py = p / w, pxx = p % w;
                if (pxx == 0 || pxx == w - 1) side = true;
                if (pxx > 0     && label[p - 1] == 0 && px[py * stride + (pxx - 1) * 4 + 3] > 170) { label[p - 1] = cur; stack[sp++] = p - 1; }
                if (pxx < w - 1 && label[p + 1] == 0 && px[py * stride + (pxx + 1) * 4 + 3] > 170) { label[p + 1] = cur; stack[sp++] = p + 1; }
                if (py > 0      && label[p - w] == 0 && px[(py - 1) * stride + pxx * 4 + 3] > 170) { label[p - w] = cur; stack[sp++] = p - w; }
                if (py < h - 1  && label[p + w] == 0 && px[(py + 1) * stride + pxx * 4 + 3] > 170) { label[p + w] = cur; stack[sp++] = p + w; }
            }
            size.Add(n); touchesSide.Add(side);
            if (n > bestSize) { bestSize = n; best = cur; }
        }

        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            int lab = label[y * w + x];
            if (lab == 0) continue;
            if (lab != best) px[y * stride + x * 4 + 3] = 0;
        }

        Marshal.Copy(px, 0, bd.Scan0, px.Length);
        bmp.UnlockBits(bd);
    }

    // Transparent pixels keep their original magenta RGB, which bleeds back as a
    // halo when the browser scales the sprite down. Push the sprite's own colour
    // outwards into the transparent band so any blend stays on-palette.
    static void BleedEdges(Bitmap bmp, int passes)
    {
        int w = bmp.Width, h = bmp.Height;
        Rectangle all = new Rectangle(0, 0, w, h);
        BitmapData bd = bmp.LockBits(all, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = bd.Stride;
        byte[] px = new byte[stride * h];
        Marshal.Copy(bd.Scan0, px, 0, px.Length);

        bool[] solid = new bool[w * h];
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
            solid[y * w + x] = px[y * stride + x * 4 + 3] > 0;

        int[] dx = { -1, 1, 0, 0 };
        int[] dy = { 0, 0, -1, 1 };
        for (int pass = 0; pass < passes; pass++)
        {
            bool[] next = (bool[])solid.Clone();
            for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                if (solid[y * w + x]) continue;
                for (int k = 0; k < 4; k++)
                {
                    int nx = x + dx[k], ny = y + dy[k];
                    if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                    if (!solid[ny * w + nx]) continue;
                    int to = y * stride + x * 4, from = ny * stride + nx * 4;
                    px[to] = px[from]; px[to + 1] = px[from + 1]; px[to + 2] = px[from + 2];
                    next[y * w + x] = true;
                    break;
                }
            }
            solid = next;
        }

        // Anything the bleed never reached keeps leftover magenta RGB under a
        // zero alpha. Nothing renders it, but tools that flatten the file show
        // it, so neutralise it to white.
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
        {
            int i = y * stride + x * 4;
            if (px[i + 3] == 0 && !solid[y * w + x])
            { px[i] = 255; px[i + 1] = 255; px[i + 2] = 255; }
        }

        Marshal.Copy(px, 0, bd.Scan0, px.Length);
        bmp.UnlockBits(bd);
    }

    static Bitmap Trim(Bitmap bmp, int pad)
    {
        int w = bmp.Width, h = bmp.Height;
        Rectangle all = new Rectangle(0, 0, w, h);
        BitmapData bd = bmp.LockBits(all, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = bd.Stride;
        byte[] px = new byte[stride * h];
        Marshal.Copy(bd.Scan0, px, 0, px.Length);
        bmp.UnlockBits(bd);

        int x0 = w, y0 = h, x1 = -1, y1 = -1;
        for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
            if (px[y * stride + x * 4 + 3] > 40)
            {
                if (x < x0) x0 = x;
                if (x > x1) x1 = x;
                if (y < y0) y0 = y;
                if (y > y1) y1 = y;
            }
        if (x1 < 0) return bmp;

        x0 = Math.Max(0, x0 - pad); y0 = Math.Max(0, y0 - pad);
        x1 = Math.Min(w - 1, x1 + pad); y1 = Math.Min(h - 1, y1 + pad);
        return bmp.Clone(new Rectangle(x0, y0, x1 - x0 + 1, y1 - y0 + 1), PixelFormat.Format32bppArgb);
    }

    static Bitmap Load(string inPath, out int w, out int h, out int stride, out byte[] px)
    {
        Bitmap loaded = new Bitmap(inPath);
        w = loaded.Width; h = loaded.Height;
        Bitmap src = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (Graphics gr = Graphics.FromImage(src)) { gr.DrawImage(loaded, 0, 0, w, h); }
        loaded.Dispose();

        Rectangle all = new Rectangle(0, 0, w, h);
        BitmapData bd = src.LockBits(all, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        stride = bd.Stride;
        px = new byte[stride * h];
        Marshal.Copy(bd.Scan0, px, 0, px.Length);

        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
            {
                int i = row + x * 4;              // BGRA
                int b = px[i], g = px[i + 1], r = px[i + 2];
                int score = Math.Min(r, b) - g;
                if (r < 90 || b < 70) score = 0;  // leave dark pixels alone

                int alpha;
                if (score >= FullKey) alpha = 0;
                else if (score <= NoKey) alpha = 255;
                else alpha = (int)(255.0 * (FullKey - score) / (FullKey - NoKey));
                px[i + 3] = (byte)alpha;
            }
        }
        Marshal.Copy(px, 0, bd.Scan0, px.Length);
        src.UnlockBits(bd);
        return src;
    }

    public static string[] Cut(string inPath, string outDir, string prefix,
                               int minGap, int minWidth, int pad, int minCol, int inset)
    {
        int w, h, stride;
        byte[] px;
        Bitmap src = Load(inPath, out w, out h, out stride, out px);

        int[] colCount = new int[w];
        for (int y = 0; y < h; y++)
        {
            int row = y * stride;
            for (int x = 0; x < w; x++)
                if (px[row + x * 4 + 3] > 40) colCount[x]++;
        }

        // Find columns that hold content; merge runs separated by a narrow gap.
        List<int[]> runs = new List<int[]>();
        int start = -1, gap = 0;
        for (int x = 0; x < w; x++)
        {
            if (colCount[x] > minCol)
            {
                if (start < 0) start = x;
                gap = 0;
            }
            else if (start >= 0)
            {
                gap++;
                if (gap >= minGap) { runs.Add(new int[] { start, x - gap }); start = -1; gap = 0; }
            }
        }
        if (start >= 0) runs.Add(new int[] { start, w - 1 });

        // minCol is set high enough to break the sheet apart despite the faint
        // vignette left in the background. That clips thin extremities, so grow
        // each run back outwards over any column that still holds real content,
        // stopping halfway to the neighbouring sprite.
        int edge = Math.Max(2, minCol / 10);
        for (int k = 0; k < runs.Count; k++)
        {
            int leftLimit  = (k == 0) ? 0 : (runs[k - 1][1] + runs[k][0]) / 2;
            int rightLimit = (k == runs.Count - 1) ? w - 1 : (runs[k][1] + runs[k + 1][0]) / 2;
            while (runs[k][0] > leftLimit  && colCount[runs[k][0] - 1] > edge) runs[k][0]--;
            while (runs[k][1] < rightLimit && colCount[runs[k][1] + 1] > edge) runs[k][1]++;
        }

        List<string> saved = new List<string>();
        int n = 0;
        foreach (int[] run in runs)
        {
            if (run[1] - run[0] + 1 < minWidth) continue;

            int top = -1, bottom = -1;
            for (int y = 0; y < h; y++)
            {
                bool any = false;
                int row = y * stride;
                for (int x = run[0]; x <= run[1]; x++)
                    if (px[row + x * 4 + 3] > 40) { any = true; break; }
                if (any) { if (top < 0) top = y; bottom = y; }
            }
            if (top < 0) continue;

            // inset shaves the sides before the blob pass, so a neighbour's hair
            // that touches this sprite is cut loose and then dropped.
            int x0 = Math.Max(0, run[0] + inset);
            int y0 = Math.Max(0, top - pad);
            int x1 = Math.Min(w - 1, run[1] - inset);
            int y1 = Math.Min(h - 1, bottom + pad);
            if (x1 <= x0) continue;

            n++;
            Rectangle crop = new Rectangle(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
            using (Bitmap raw = src.Clone(crop, PixelFormat.Format32bppArgb))
            {
                DropEdgeFragments(raw);
                using (Bitmap outBmp = Trim(raw, pad))
                {
                    BleedEdges(outBmp, 4);
                    string path = System.IO.Path.Combine(outDir, prefix + "-" + n + ".png");
                    outBmp.Save(path, ImageFormat.Png);
                    saved.Add(prefix + "-" + n + ".png  " + outBmp.Width + "x" + outBmp.Height);
                }
            }
        }
        src.Dispose();
        return saved.ToArray();
    }
}
'@

if (-not ([System.Management.Automation.PSTypeName]'SpriteCutter').Type) {
  Add-Type -TypeDefinition $code -ReferencedAssemblies "System.Drawing" -ErrorAction Stop
}

$inFull  = (Resolve-Path $In).Path
$outFull = (Resolve-Path $OutDir).Path

if ($Profile) {
  $p = [SpriteCutter]::Profile($inFull)
  # print one bucket per 16 columns so the gaps are visible at a glance
  $buckets = for ($i = 0; $i -lt $p.Length; $i += 16) {
    $slice = $p[$i..([Math]::Min($i + 15, $p.Length - 1))]
    ($slice | Measure-Object -Maximum).Maximum
  }
  ($buckets | ForEach-Object { if ($_ -gt 40) { "#" } elseif ($_ -gt 4) { "+" } elseif ($_ -gt 0) { "." } else { " " } }) -join ""
  return
}

[SpriteCutter]::Cut($inFull, $outFull, $Prefix, $MinGap, $MinWidth, $Pad, $MinCol, $Inset)

