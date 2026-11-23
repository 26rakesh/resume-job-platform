# Build React frontend and copy to Laravel public directory
# Run this before committing or deploying

$ErrorActionPreference = "Stop"

Write-Host "Building React frontend..." -ForegroundColor Cyan
Set-Location frontend
npm ci
npm run build

Write-Host "Copying build output to Laravel public/app..." -ForegroundColor Cyan
Set-Location ..
if (Test-Path backend\public\app) {
    Remove-Item backend\public\app -Recurse -Force
}
Copy-Item frontend\dist -Destination backend\public\app -Recurse

Write-Host "Build complete! Frontend assets copied to backend/public/app" -ForegroundColor Green
