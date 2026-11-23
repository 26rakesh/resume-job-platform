#!/bin/bash
# Build React frontend and copy to Laravel public directory
# Run this before committing or deploying

set -e

echo "Building React frontend..."
cd frontend
NODE_ENV=production npm ci
NODE_ENV=production npm run build

echo "Copying build output to Laravel public/app..."
cd ..
rm -rf backend/public/app
cp -r frontend/dist backend/public/app

echo "Build complete! Frontend assets copied to backend/public/app"
echo "Laravel serves the SPA via the fallback route in routes/web.php"
echo "React Router handles client-side routing (/, /candidates, /jobs, /settings, etc.)"
echo "For Hostinger deployment:"
echo "  - Preferred: Copy repository to /home/<user>/jobs-platform/"
echo "  - Subdomain document root: /home/<user>/jobs-platform/backend/public"
echo "  - Alternative: Copy repository to /home/<user>/domains/jobs.sunrisepaint.in/public_html/"
