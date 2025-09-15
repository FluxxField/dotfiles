[CmdletBinding()]
param(
  [switch]$NoDownload  # only install from local_dir if set
)

$ErrorActionPreference = 'Stop'
# Ensure modern TLS in Windows PowerShell
if ($PSVersionTable.PSVersion.Major -lt 6) {
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
}

function Get-RepoRoot {
  Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

function Get-UserFontsDir {
  # Per-user fonts (no admin required)
  Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
}

function Ensure-Dir($path) {
  if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

function Install-FontsFromDir($srcDir, $userFonts) {
  $installed = @()
  Get-ChildItem -Path $srcDir -Recurse -Include *.ttf,*.otf -ErrorAction SilentlyContinue | ForEach-Object {
    $target = Join-Path $userFonts $_.Name
    Copy-Item $_.FullName $target -Force
    $installed += $target
  }
  $installed
}

function Refresh-FontCache {
  # Broadcast WM_FONTCHANGE so apps refresh font list
  Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError=true)]
public static extern int SendMessageTimeout(int hWnd, int Msg, int wParam, int lParam, int fuFlags, int uTimeout, out System.IntPtr lpdwResult);
"@
  $HWND_BROADCAST = 0xffff
  $WM_FONTCHANGE  = 0x001D
  $SMTO_NORMAL    = 0x0000
  [System.IntPtr]$res = [System.IntPtr]::Zero
  [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_FONTCHANGE, 0, 0, $SMTO_NORMAL, 1000, [ref]$res) | Out-Null
}

# -------- Load shared manifest --------
$root = Get-RepoRoot
$manifestPath = Join-Path $root 'fonts\manifest.json'
if (-not (Test-Path $manifestPath)) {
  throw "Manifest not found: $manifestPath"
}
$mf = Get-Content $manifestPath -Raw | ConvertFrom-Json
$families = @($mf.nerd_fonts) | Where-Object { $_ -and $_.Trim() -ne '' }
$includeSymbols = [bool]$mf.include_symbols
$extraUrls = @($mf.extra_urls)
$localDir = if ($mf.local_dir) { Join-Path $root $mf.local_dir } else { $null }

$userFonts = Get-UserFontsDir
Ensure-Dir $userFonts
$installedFiles = @()

# 1) Nerd Fonts families from latest release
if (-not $NoDownload) {
  $tmp = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),[System.Guid]::NewGuid())) -Force
  try {
    foreach ($name in $families) {
      $zip = Join-Path $tmp.FullName "$name.zip"
      $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$name.zip"
      Write-Host "Downloading $name Nerd Font..."
      Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
      $unzip = Join-Path $tmp.FullName $name
      Expand-Archive -Path $zip -DestinationPath $unzip -Force
      $installedFiles += Install-FontsFromDir -srcDir $unzip -userFonts $userFonts
    }
    if ($includeSymbols) {
      $symZip = Join-Path $tmp.FullName "NerdFontsSymbolsOnly.zip"
      $symUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip"
      Write-Host "Downloading NerdFontsSymbolsOnly.zip..."
      Invoke-WebRequest -UseBasicParsing -Uri $symUrl -OutFile $symZip
      $symUnz = Join-Path $tmp.FullName "SymbolsOnly"
      Expand-Archive -Path $symZip -DestinationPath $symUnz -Force
      $installedFiles += Install-FontsFromDir -srcDir $symUnz -userFonts $userFonts
    }
  } finally {
    Remove-Item $tmp.FullName -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# 2) Extra URLs (ttf/otf/zip)
foreach ($u in $extraUrls) {
  if (-not $u) { continue }
  $tmpFile = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName() + (Split-Path $u -Leaf))
  Write-Host "Downloading font: $u"
  Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $tmpFile
  $ext = [IO.Path]::GetExtension($tmpFile)
  if ($ext -match '\.zip') {
    $unz = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
    Expand-Archive -Path $tmpFile -DestinationPath $unz -Force
    $installedFiles += Install-FontsFromDir -srcDir $unz -userFonts $userFonts
    Remove-Item $unz -Recurse -Force -ErrorAction SilentlyContinue
  } else {
    Copy-Item $tmpFile (Join-Path $userFonts (Split-Path $tmpFile -Leaf)) -Force
    $installedFiles += (Join-Path $userFonts (Split-Path $tmpFile -Leaf))
  }
  Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
}

# 3) Local repo fonts
if ($localDir -and (Test-Path $localDir)) {
  $installedFiles += Install-FontsFromDir -srcDir $localDir -userFonts $userFonts
}

Refresh-FontCache
Write-Host ""
Write-Host "Installed/updated fonts (${installedFiles.Count} files) into:"
Write-Host "  $userFonts"
Write-Host "Done."
