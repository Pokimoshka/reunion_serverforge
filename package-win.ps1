# =============================================================================
# Package the full Windows distribution of ReUnion (DLL + config + docs + samples)
# =============================================================================
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Version = "0.2.0.0"

$PublishDir = Join-Path $RepoRoot "build\output\windows-full"
$ReunionDir = Join-Path $PublishDir "addons\reunion"
$ScriptingDir = Join-Path $PublishDir "addons\amxmodx\scripting"
$SrcDir = Join-Path $PublishDir "src"

# Clean and create directories
if (Test-Path $PublishDir) { Remove-Item -Recurse -Force $PublishDir }
New-Item -ItemType Directory -Path $ReunionDir -Force | Out-Null
New-Item -ItemType Directory -Path $ScriptingDir -Force | Out-Null
New-Item -ItemType Directory -Path $SrcDir -Force | Out-Null

# 1. DLL
$Dll = Join-Path $RepoRoot "build\output\windows\addons\reunion\reunion_mm.dll"
if (-not (Test-Path $Dll)) {
    Write-Error "reunion_mm.dll not found. Run build-win.bat first."
    exit 1
}
Copy-Item $Dll $ReunionDir

# 2. Config
Copy-Item (Join-Path $RepoRoot "reunion\dist\reunion.cfg") $PublishDir

# 3. Readme.txt (generated from template)
$Tpl = Get-Content (Join-Path $RepoRoot "reunion\dist\Readme.tpl") -Raw
$Readme = $Tpl.Replace('${APP_VERSION_STRD}', $Version)
Set-Content -Path (Join-Path $PublishDir "Readme.txt") -Value $Readme -NoNewline -Encoding UTF8

# 4. API header
Copy-Item (Join-Path $RepoRoot "reunion\src\reunion_api.h") $SrcDir

# 5. AMXX samples
Copy-Item (Join-Path $RepoRoot "reunion\extra\reu_test.sma") $ScriptingDir
Copy-Item (Join-Path $RepoRoot "reunion\extra\updatehint.sma") $ScriptingDir
Copy-Item (Join-Path $RepoRoot "reunion\extra\updatehint.txt") $ScriptingDir

# 6. Create zip archive
$ZipPath = Join-Path $RepoRoot "build\output\reunion-$Version-windows.zip"
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path (Join-Path $PublishDir "*") -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "=== Windows package created ===" -ForegroundColor Green
Write-Host "Zip:    $ZipPath" -ForegroundColor Green
Write-Host "Folder: $PublishDir" -ForegroundColor Green
Write-Host ""
Get-ChildItem -Recurse $PublishDir | ForEach-Object { $_.FullName.Replace($PublishDir + "\", "") }
