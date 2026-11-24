# Build React frontend and copy to Laravel public directory
# Run this before committing or deploying

$ErrorActionPreference = "Stop"

Write-Host "Building React frontend..." -ForegroundColor Cyan
Set-Location frontend
$env:NODE_ENV = "production"
npm ci
npm run build

Write-Host "Copying build output to Laravel public/app..." -ForegroundColor Cyan
Set-Location ..
if (Test-Path backend\public\app) {
    Remove-Item backend\public\app -Recurse -Force
}
Copy-Item frontend\dist -Destination backend\public\app -Recurse

Write-Host "Build complete! Frontend assets copied to backend/public/app" -ForegroundColor Green
Write-Host "Laravel serves the SPA via the fallback route in routes/web.php" -ForegroundColor Cyan
Write-Host "React Router handles client-side routing (/, /candidates, /jobs, /settings, etc.)" -ForegroundColor Cyan
Write-Host "For Hostinger deployment:" -ForegroundColor Yellow
Write-Host "  - Preferred: Copy repository to /home/<user>/jobs-platform/" -ForegroundColor Yellow
Write-Host "  - Subdomain document root: /home/<user>/jobs-platform/backend/public" -ForegroundColor Yellow
Write-Host "  - Alternative: Copy repository to /home/<user>/domains/jobs.sunrisepaint.in/public_html/" -ForegroundColor Yellow
