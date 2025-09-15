[CmdletBinding()]
param(
  [ValidateSet('Copy','Symlink')]
  [string]$Mode = 'Copy'  # 'Symlink' needs admin or Dev Mode
)

$ErrorActionPreference = 'Stop'

# Repo root = ..\.. from this script
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$srcDir   = Join-Path $repoRoot 'win\windows-terminal'
$srcFile  = Join-Path $srcDir 'settings.json'

if (-not (Test-Path $srcFile)) {
  throw "Source settings not found: $srcFile"
}

# Windows Terminal install locations
$storeDir      = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
$unpackagedDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal'

# Prefer whichever exists; default to Store path
$targetDir = if (Test-Path $storeDir) { $storeDir }
             elseif (Test-Path $unpackagedDir) { $unpackagedDir }
             else { $storeDir }

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
$targetFile = Join-Path $targetDir 'settings.json'

# Backup existing non-link file
if (Test-Path $targetFile) {
  $isLink = (Get-Item $targetFile).Attributes -band [IO.FileAttributes]::ReparsePoint
  if (-not $isLink) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $targetFile "$targetFile.$stamp.bak"
  }
}

if ($Mode -eq 'Symlink') {
  # Requires admin or Developer Mode
  if (Test-Path $targetFile) { Remove-Item $targetFile -Force }
  New-Item -ItemType SymbolicLink -Path $targetFile -Value $srcFile | Out-Null
  Write-Host "Linked $targetFile -> $srcFile"
} else {
  Copy-Item $srcFile $targetFile -Force
  Write-Host "Copied $srcFile -> $targetFile"
}

# Optional: copy extra assets like schemes.json if present
$extra = Join-Path $srcDir 'schemes.json'
if (Test-Path $extra) {
  Copy-Item $extra (Join-Path $targetDir 'schemes.json') -Force
}
