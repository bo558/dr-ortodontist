<#
  Local preview server for dist/ (no dependencies). Listens on localhost only.
  Runs on Windows PowerShell 5.1 and PowerShell 7+ (Windows, macOS, Linux).

  Usage:
    pwsh -File serve.ps1                                   http://localhost:4173/
    pwsh -File serve.ps1 -Port 5000
    pwsh -File serve.ps1 -BasePath /dr-ortodontist/        http://localhost:4173/dr-ortodontist/
      (use the same -BasePath that was passed to build.ps1 to simulate GitHub Pages)
#>
param(
  [int]$Port = 4173,
  [string]$BasePath = '/'
)

$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, 'dist'))
if (-not (Test-Path -LiteralPath $root)) { throw "dist/ not found. Run build.ps1 first." }
$rootWithSep = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar

$BasePath = '/' + $BasePath.Trim().Trim('/')
if (-not $BasePath.EndsWith('/')) { $BasePath += '/' }

$types = @{
  '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.js' = 'application/javascript; charset=utf-8'; '.json' = 'application/json; charset=utf-8'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'
  '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'
  '.xml' = 'application/xml; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Dr. Ortodontist preview: http://localhost:$Port$BasePath  (Ctrl+C to stop)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
      $urlPath = $req.Url.AbsolutePath
      $res.Headers.Add('Cache-Control', 'no-cache')
      $res.Headers.Add('X-Robots-Tag', 'noindex, nofollow')
      $status = 200
      $redirect = $null
      $full = $null

      if ($BasePath -ne '/' -and ($urlPath + '/') -eq $BasePath) {
        $redirect = $BasePath
      } elseif ($urlPath.StartsWith($BasePath)) {
        $rel = [Uri]::UnescapeDataString($urlPath.Substring($BasePath.Length))
        $segments = @($rel -split '/' | Where-Object { $_ -ne '' })
        $full = [IO.Path]::GetFullPath([IO.Path]::Combine([string[]](@($root) + $segments)))
        if ($full -ne $root -and -not $full.StartsWith($rootWithSep)) {
          $status = 403; $full = $null
        } elseif (Test-Path -LiteralPath $full -PathType Container) {
          if (-not $urlPath.EndsWith('/')) { $redirect = "$urlPath/" }
          else { $full = [IO.Path]::Combine($full, 'index.html') }
        }
      } else {
        $status = 404
      }

      if ($redirect) {
        $res.StatusCode = 301
        $res.RedirectLocation = $redirect
      } else {
        if (-not $full -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
          if ($status -eq 200) { $status = 404 }
          $full = [IO.Path]::Combine($root, '404.html')
        }
        $bytes = [IO.File]::ReadAllBytes($full)
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $res.StatusCode = $status
        $res.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' })
        $res.ContentLength64 = $bytes.Length
        if ($req.HttpMethod -ne 'HEAD') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
      }
      Write-Host ("{0} {1} {2}" -f $res.StatusCode, $req.HttpMethod, $urlPath)
    } catch {
      $res.StatusCode = 500
    } finally {
      $res.Close()
    }
  }
} finally {
  $listener.Stop()
}
