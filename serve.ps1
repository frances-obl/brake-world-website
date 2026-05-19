$port = 5501
$root = $PSScriptRoot

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$port/"

$mimeTypes = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.json' = 'application/json'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif'  = 'image/gif'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.woff' = 'font/woff'
  '.woff2'= 'font/woff2'
}

while ($listener.IsListening) {
  $ctx = $null
  try { $ctx = $listener.GetContext() } catch { continue }
  $req = $ctx.Request
  $res = $ctx.Response

  try {
    $localPath = $req.Url.LocalPath.TrimStart('/') -replace '/', [System.IO.Path]::DirectorySeparatorChar
    if ($localPath -eq '' -or $localPath -eq '\') { $localPath = 'index.html' }
    $file = Join-Path $root $localPath

    if (Test-Path $file -PathType Leaf) {
      $ext  = [System.IO.Path]::GetExtension($file).ToLower()
      $mime = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { 'application/octet-stream' }
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $res.StatusCode  = 200
      $res.ContentType = $mime
      $res.SendChunked = $true
      $stream = $res.OutputStream
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush()
    } else {
      $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
      $res.StatusCode  = 404
      $res.ContentType = 'text/plain'
      $res.SendChunked = $true
      $res.OutputStream.Write($body, 0, $body.Length)
    }
  } catch {
    Write-Warning "Serve error [$($req.Url.LocalPath)]: $_"
    try { $res.Abort() } catch {}
    continue
  } finally {
    try { $res.OutputStream.Close() } catch {}
  }
}
