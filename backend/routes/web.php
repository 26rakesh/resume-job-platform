<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\File;

// Serve React SPA for all non-API routes
// API routes are handled in routes/api.php with /api prefix
// React assets are at public/app/ with base path configured in vite.config.ts
Route::get('/{any}', function () {
    $indexPath = public_path('app/index.html');

    if (!File::exists($indexPath)) {
        abort(404, 'React application not built. Run: npm run build && copy frontend/dist to backend/public/app');
    }

    return File::get($indexPath);
})->where('any', '^(?!api).*')->fallback();

