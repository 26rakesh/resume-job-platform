#!/bin/bash
# Build React frontend and copy to Laravel public directory
# Run this before committing or deploying

set -e

echo "Building React frontend..."
cd frontend
npm ci
npm run build

echo "Copying build output to Laravel public/app..."
cd ..
rm -rf backend/public/app
cp -r frontend/dist backend/public/app

echo "Build complete! Frontend assets copied to backend/public/app"
