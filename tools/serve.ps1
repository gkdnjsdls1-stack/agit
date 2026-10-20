# Minimal static file server for previewing the game locally.
#   .\tools\serve.ps1 -Port 8765
param([int]$Port = 8765, [string]$Root = (Split-Path $PSScriptRoot -Parent))

$types = @{
  ".html" = "text/html; charset=utf-8"
  ".js"   = "text/javascript; charset=utf-8"
  ".css"  = "text/css; charset=utf-8"
  ".png"  = "image/png"
  ".jpg"  = "image/jpeg"
  ".svg"  = "image/svg+xml"
  ".json" = "application/json; charset=utf-8"
  ".webmanifest" = "application/manifest+json; charset=utf-8"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "serving $Root on http://localhost:$Port/"

# One bad request must never take the server down: every iteration is guarded,
# and the response is closed in finally.
while ($listener.IsListening) {
  $ctx = $null
  try {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($rel -eq "") { $rel = "index.html" }
    $path = Join-Path $Root $rel

    if (Test-Path $path -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($path).ToLower()
      $ctx.Response.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
      $ctx.Response.Headers["Cache-Control"] = "no-store"
      if ($ctx.Request.HttpMethod -eq "HEAD") {
        Write-Output "200 (head) $rel"
      } else {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        Write-Output "200 $rel"
      }
    } else {
      $ctx.Response.StatusCode = 404
      Write-Output "404 $rel"
    }
  } catch {
    Write-Output "ERR $($_.Exception.Message)"
  } finally {
    if ($ctx) { try { $ctx.Response.Close() } catch {} }
  }
}
