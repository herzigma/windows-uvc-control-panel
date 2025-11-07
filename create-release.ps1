# Script to create GitHub release and upload executables
# Requires GitHub Personal Access Token with 'repo' scope

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [string]$Tag = "v1.0.0",
    [string]$ReleaseName = "Version 1.0.0",
    [string]$Owner = "herzigma",
    [string]$Repo = "windows-uvc-control-panel"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating GitHub release: $Tag" -ForegroundColor Cyan

# Check if executables exist
$x64Exe = "publish\win-x64\UvcPaneler.exe"
$x86Exe = "publish\win-x86\UvcPaneler.exe"

if (-not (Test-Path $x64Exe)) {
    Write-Host "Error: $x64Exe not found. Run build first." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $x86Exe)) {
    Write-Host "Error: $x86Exe not found. Run build first." -ForegroundColor Red
    exit 1
}

# Release notes
$releaseNotes = "## Version 1.0.0 - Initial Release`n`nInitial release of Windows UVC Control Panel.`n`n### Features`n- DirectShow integration for accessing camera property pages`n- Support for Windows 10 and Windows 11 (32-bit and 64-bit)`n- Camera enumeration and selection`n- Multiple access methods (UVC DirectShow, Legacy VfW, Media Foundation info)`n- Built-in logging`n`n### Downloads`n- **UvcPaneler-x64.exe**: 64-bit Windows executable (self-contained, no .NET runtime required)`n- **UvcPaneler-x86.exe**: 32-bit Windows executable (self-contained, no .NET runtime required)`n`n### Requirements`n- Windows 10 (version 19041 or later) or Windows 11`n- USB Video Class (UVC) camera`n`n### Usage`n1. Run the appropriate executable for your system`n2. Select your camera from the list`n3. Click `"Open UVC (DirectShow)…`" to access camera settings"

# Create release body JSON
$releaseBodyObj = @{
    tag_name = $Tag
    name = $ReleaseName
    body = $releaseNotes
    draft = $false
    prerelease = $false
}
$releaseBody = $releaseBodyObj | ConvertTo-Json -Compress

# Create the release
Write-Host "Creating release on GitHub..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
    "Content-Type" = "application/json"
}

try {
    $createUrl = "https://api.github.com/repos/$Owner/$Repo/releases"
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($releaseBody)
    $response = Invoke-RestMethod -Uri $createUrl -Method Post -Headers $headers -Body $utf8Bytes
    
    $releaseId = $response.id
    Write-Host "Release created! ID: $releaseId" -ForegroundColor Green
    
    # Upload x64 executable
    Write-Host "Uploading x64 executable..." -ForegroundColor Yellow
    try {
        $x64UploadUrl = "https://uploads.github.com/repos/$Owner/$Repo/releases/$releaseId/assets?name=UvcPaneler-x64.exe"
        $x64Bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $x64Exe))
        $x64Headers = @{
            "Authorization" = "token $GitHubToken"
            "Content-Type" = "application/octet-stream"
        }
        $x64Result = Invoke-RestMethod -Uri $x64UploadUrl -Method Post -Headers $x64Headers -Body $x64Bytes
        Write-Host "✓ x64 executable uploaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to upload x64 executable: $_" -ForegroundColor Red
        throw
    }
    
    # Upload x86 executable
    Write-Host "Uploading x86 executable..." -ForegroundColor Yellow
    try {
        $x86UploadUrl = "https://uploads.github.com/repos/$Owner/$Repo/releases/$releaseId/assets?name=UvcPaneler-x86.exe"
        $x86Bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $x86Exe))
        $x86Headers = @{
            "Authorization" = "token $GitHubToken"
            "Content-Type" = "application/octet-stream"
        }
        $x86Result = Invoke-RestMethod -Uri $x86UploadUrl -Method Post -Headers $x86Headers -Body $x86Bytes
        Write-Host "✓ x86 executable uploaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to upload x86 executable: $_" -ForegroundColor Red
        throw
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Release created successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Release URL: $($response.html_url)" -ForegroundColor Yellow
    Write-Host "`nYour release is now live on GitHub!" -ForegroundColor Green
    
} catch {
    Write-Host "Error creating release: $_" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response)" -ForegroundColor Red
    exit 1
}

