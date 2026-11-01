# =============================================================================
# PowerShell скрипт для сборки ReUnion через Docker (Windows хост)
# =============================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("linux", "windows", "all", "clean")]
    [string]$Target = "all",

    [switch]$NoCache
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ImageLinux = "reunion-build-linux"
$ImageWindows = "reunion-build-windows"
$ContainerLinux = "reunion-build-linux-container"
$ContainerWindows = "reunion-build-windows-container"

function Ensure-Docker {
    try {
        docker info | Out-Null
    } catch {
        Write-Error "Docker не запущен или не установлен. Установите Docker Desktop и попробуйте снова."
        exit 1
    }
}

function Cleanup {
    Write-Host "=== Очистка Docker-ресурсов ===" -ForegroundColor Cyan
    docker rm -f $ContainerLinux 2>$null -ErrorAction SilentlyContinue
    docker rm -f $ContainerWindows 2>$null -ErrorAction SilentlyContinue
    docker rmi -f $ImageLinux 2>$null -ErrorAction SilentlyContinue
    docker rmi -f $ImageWindows 2>$null -ErrorAction SilentlyContinue
    Write-Host "Готово." -ForegroundColor Green
}

function Build-Linux {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Сборка ReUnion под Linux (Docker)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    Ensure-Docker

    $cacheArg = ""
    if ($NoCache) { $cacheArg = "--no-cache" }

    Write-Host "Сборка Docker-образа: $ImageLinux" -ForegroundColor Yellow
    docker build $cacheArg -f "$RepoRoot/Dockerfile.linux" -t $ImageLinux "$RepoRoot"

    Write-Host "Извлечение артефактов из контейнера..." -ForegroundColor Yellow
    docker rm -f $ContainerLinux 2>$null -ErrorAction SilentlyContinue
    docker create --name $ContainerLinux $ImageLinux | Out-Null

    $outDir = "$RepoRoot\build\output\linux"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    docker cp "$ContainerLinux:/publish/." $outDir | Out-Null
    docker rm -f $ContainerLinux >$null

    Write-Host "" -ForegroundColor Green
    Write-Host "=== Linux сборка завершена ===" -ForegroundColor Green
    Write-Host "Артефакты: $outDir" -ForegroundColor Green
    Get-ChildItem "$outDir\addons\reunion\" -ErrorAction SilentlyContinue
}

function Build-Windows {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Сборка ReUnion под Windows (Docker)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    Ensure-Docker

    $cacheArg = ""
    if ($NoCache) { $cacheArg = "--no-cache" }

    Write-Host "Сборка Docker-образа: $ImageWindows (может занять 20-40 мин)" -ForegroundColor Yellow
    docker build $cacheArg -f "$RepoRoot/Dockerfile.windows" -t $ImageWindows "$RepoRoot"

    Write-Host "Извлечение артефактов из контейнера..." -ForegroundColor Yellow
    docker rm -f $ContainerWindows 2>$null -ErrorAction SilentlyContinue
    docker create --name $ContainerWindows $ImageWindows | Out-Null

    $outDir = "$RepoRoot\build\output\windows"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    docker cp "$ContainerWindows:C:\publish\." $outDir | Out-Null
    docker rm -f $ContainerWindows >$null

    Write-Host "" -ForegroundColor Green
    Write-Host "=== Windows сборка завершена ===" -ForegroundColor Green
    Write-Host "Артефакты: $outDir" -ForegroundColor Green
    Get-ChildItem "$outDir\addons\reunion\" -ErrorAction SilentlyContinue
}

switch ($Target) {
    "clean" { Cleanup }
    "linux" { Build-Linux }
    "windows" { Build-Windows }
    "all"   { Build-Linux; Build-Windows }
}
