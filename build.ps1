# Build script for Windows UVC Control Panel
# Creates both x64 and x86 self-contained executables

param(
    [string]$Configuration = "Release",
    [switch]$SelfContained = $true,
    [switch]$FrameworkDependent = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Building Windows UVC Control Panel..." -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow

# Clean previous publish outputs
if (Test-Path "publish") {
    Write-Host "Cleaning previous publish outputs..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "publish"
}

# Create publish directory
New-Item -ItemType Directory -Path "publish" -Force | Out-Null

$runtimes = @("win-x64", "win-x86")
$buildCount = 0

foreach ($runtime in $runtimes) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Building for $runtime..." -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $outputPath = "publish\$runtime"
    
    if ($SelfContained) {
        Write-Host "Creating self-contained executable..." -ForegroundColor Yellow
        dotnet publish `
            -c $Configuration `
            -r $runtime `
            --self-contained true `
            -p:PublishSingleFile=true `
            -p:IncludeNativeLibrariesForSelfExtract=true `
            -p:EnableCompressionInSingleFile=true `
            -o $outputPath
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed for $runtime" -ForegroundColor Red
            exit 1
        }
        
        $buildCount++
        Write-Host "✓ Self-contained build completed for $runtime" -ForegroundColor Green
    }
    
    if ($FrameworkDependent) {
        Write-Host "Creating framework-dependent executable..." -ForegroundColor Yellow
        $fdOutputPath = "$outputPath-fd"
        
        dotnet publish `
            -c $Configuration `
            -r $runtime `
            --self-contained false `
            -p:PublishSingleFile=true `
            -o $fdOutputPath
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed for $runtime (framework-dependent)" -ForegroundColor Red
            exit 1
        }
        
        $buildCount++
        Write-Host "✓ Framework-dependent build completed for $runtime" -ForegroundColor Green
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Completed $buildCount build(s)" -ForegroundColor Green
Write-Host "`nOutput location: publish\" -ForegroundColor Yellow
Write-Host "`nExecutables are ready for distribution!" -ForegroundColor Green

# List created files
Write-Host "`nCreated files:" -ForegroundColor Yellow
Get-ChildItem -Path "publish" -Recurse -Filter "*.exe" | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  $($_.FullName) ($size MB)" -ForegroundColor Gray
}

