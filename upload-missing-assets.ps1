# Script to upload missing assets to an existing GitHub release
# This will add the x86 executable to the v1.0.0 release

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [string]$Tag = "v1.0.0",
    [string]$Owner = "herzigma",
    [string]$Repo = "windows-uvc-control-panel"
)

$ErrorActionPreference = "Stop"

Write-Host "Uploading missing assets to release: $Tag" -ForegroundColor Cyan

# Check if executables exist
$x86Exe = "publish\win-x86\UvcPaneler.exe"

if (-not (Test-Path $x86Exe)) {
    Write-Host "Error: $x86Exe not found. Run build first." -ForegroundColor Red
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
    
    # Check existing assets
    Write-Host ""
    Write-Host "Existing assets:" -ForegroundColor Yellow
    foreach ($asset in $release.assets) {
        $sizeMB = [math]::Round($asset.size / 1MB, 2)
        Write-Host "  - $($asset.name) ($sizeMB MB)" -ForegroundColor Gray
    }
    
    # Upload x86 executable if not already present
    $x86Exists = $release.assets | Where-Object { $_.name -eq "UvcPaneler-x86.exe" }
    
    if ($x86Exists) {
        Write-Host ""
        Write-Host "UvcPaneler-x86.exe already exists in release. Skipping upload." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Uploading x86 executable..." -ForegroundColor Yellow
        $x86UploadUrl = "https://uploads.github.com/repos/$Owner/$Repo/releases/$releaseId/assets?name=UvcPaneler-x86.exe"
        $x86Bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $x86Exe))
        $x86Headers = @{
            "Authorization" = "token $GitHubToken"
            "Content-Type" = "application/octet-stream"
        }
        $x86Result = Invoke-RestMethod -Uri $x86UploadUrl -Method Post -Headers $x86Headers -Body $x86Bytes
        Write-Host "x86 executable uploaded successfully" -ForegroundColor Green
        Write-Host "  File: $($x86Result.name)" -ForegroundColor Gray
    }
    
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
