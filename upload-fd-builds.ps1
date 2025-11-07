# Script to upload framework-dependent builds to an existing GitHub release

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [string]$Tag = "v1.0.0",
    [string]$Owner = "herzigma",
    [string]$Repo = "windows-uvc-control-panel"
)

$ErrorActionPreference = "Stop"

Write-Host "Uploading framework-dependent builds to release: $Tag" -ForegroundColor Cyan

# Check if executables exist
$x64FdExe = "publish\win-x64-fd\UvcPaneler.exe"
$x86FdExe = "publish\win-x86-fd\UvcPaneler.exe"

if (-not (Test-Path $x64FdExe)) {
    Write-Host "Error: $x64FdExe not found. Run build first." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $x86FdExe)) {
    Write-Host "Error: $x86FdExe not found. Run build first." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
}

try {
    # Get the release by tag
    Write-Host "Finding release for tag: $Tag" -ForegroundColor Yellow
    $getReleaseUrl = "https://api.github.com/repos/$Owner/$Repo/releases/tags/$Tag"
    $release = Invoke-RestMethod -Uri $getReleaseUrl -Method Get -Headers $headers
    $releaseId = $release.id
    
    Write-Host "Found release ID: $releaseId" -ForegroundColor Green
    
    # Upload x64 framework-dependent executable
    Write-Host ""
    Write-Host "Uploading x64 framework-dependent executable..." -ForegroundColor Yellow
    $x64FdUploadUrl = "https://uploads.github.com/repos/$Owner/$Repo/releases/$releaseId/assets?name=UvcPaneler-x64-framework-dependent.exe"
    $x64FdBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $x64FdExe))
    $x64FdHeaders = @{
        "Authorization" = "token $GitHubToken"
        "Content-Type" = "application/octet-stream"
    }
    $x64FdResult = Invoke-RestMethod -Uri $x64FdUploadUrl -Method Post -Headers $x64FdHeaders -Body $x64FdBytes
    Write-Host "x64 framework-dependent executable uploaded successfully" -ForegroundColor Green
    Write-Host "  File: $($x64FdResult.name)" -ForegroundColor Gray
    
    # Upload x86 framework-dependent executable
    Write-Host ""
    Write-Host "Uploading x86 framework-dependent executable..." -ForegroundColor Yellow
    $x86FdUploadUrl = "https://uploads.github.com/repos/$Owner/$Repo/releases/$releaseId/assets?name=UvcPaneler-x86-framework-dependent.exe"
    $x86FdBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $x86FdExe))
    $x86FdHeaders = @{
        "Authorization" = "token $GitHubToken"
        "Content-Type" = "application/octet-stream"
    }
    $x86FdResult = Invoke-RestMethod -Uri $x86FdUploadUrl -Method Post -Headers $x86FdHeaders -Body $x86FdBytes
    Write-Host "x86 framework-dependent executable uploaded successfully" -ForegroundColor Green
    Write-Host "  File: $($x86FdResult.name)" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Upload complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Release URL: $($release.html_url)" -ForegroundColor Yellow
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

