# SlideUp Release Auto-Increment Build Script
$pubspecPath = "pubspec.yaml"

if (-Not (Test-Path $pubspecPath)) {
    Write-Host "❌ Error: pubspec.yaml not found in current directory!" -ForegroundColor Red
    exit 1
}

# Read pubspec.yaml content
$content = Get-Content $pubspecPath -Raw

# Match version pattern: version: X.Y.Z+BuildNumber
if ($content -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    $versionName = $matches[1]
    $buildNumber = [int]($matches[2]) + 1
    $newVersion = "$versionName+$buildNumber"
} elseif ($content -match 'version:\s*(\d+\.\d+\.\d+)') {
    $versionName = $matches[1]
    $buildNumber = 1
    $newVersion = "$versionName+$buildNumber"
} else {
    $newVersion = "1.0.0+1"
}

# Update pubspec.yaml with new incremented version
$newContent = $content -replace 'version:\s*[^\r\n]+', "version: $newVersion"
Set-Content $pubspecPath $newContent -NoNewline

Write-Host "==========================================" -ForegroundColor Green
Write-Host "🚀 AUTO-INCREMENTED APP VERSION TO: $newVersion" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

Write-Host "`n🧹 Cleaning stale build caches..." -ForegroundColor Yellow
flutter clean

Write-Host "`n🔨 Building Compact Release Split APKs..." -ForegroundColor Cyan
flutter build apk --release --split-per-abi

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "🎉 RELEASE BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "📦 APK Location: build/app/outputs/flutter-apk/" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
