# React SPA Integration and Deep-Link Support

## Overview

The React application is built as a Single Page Application (SPA) and served through Laravel. This document explains how the integration works and how deep-linking is supported.

## Architecture

### Build Process

1. **Local Build**: React is built with Vite to static files in `frontend/dist/`
2. **Copy to Laravel**: Build output is copied to `backend/public/app/`
3. **Git Commit**: The built artifacts are committed to the repository (required for Hostinger since it doesn't run Node.js)
4. **Laravel Serves**: Laravel serves the SPA via a fallback route

### Vite Configuration

**`frontend/vite.config.ts`**:
```typescript
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  base: '/app/', // Assets served from /app/ in production
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
})
```

- `base: '/app/'` ensures assets are referenced correctly when served from Laravel's `/app/` path
- Proxy configuration allows API calls during development

### Laravel SPA Fallback Route

**`backend/routes/web.php`**:
```php
Route::get('/{any}', function () {
    $indexPath = public_path('app/index.html');

    if (!File::exists($indexPath)) {
        abort(404, 'React application not built. Run: npm run build && copy frontend/dist to backend/public/app');
    }

    return File::get($indexPath);
})->where('any', '^(?!api).*')->fallback();
```

- Serves `index.html` for all non-API routes
- API routes (`/api/*`) are excluded from the fallback
- Returns 404 if React build doesn't exist

## React Router Configuration

**`frontend/src/App.tsx`**:
```tsx
<BrowserRouter>
  <Routes>
    <Route path="/login" element={<Login />} />
    <Route path="/" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
    <Route path="/candidates" element={<ProtectedRoute><Candidates /></ProtectedRoute>} />
    <Route path="/resumes" element={<ProtectedRoute><ResumeManagement /></ProtectedRoute>} />
    <Route path="/jobs" element={<ProtectedRoute><JobDiscovery /></ProtectedRoute>} />
    <Route path="/matches" element={<ProtectedRoute><JobMatches /></ProtectedRoute>} />
    <Route path="/applications" element={<ProtectedRoute><Applications /></ProtectedRoute>} />
    <Route path="/settings" element={<ProtectedRoute><Settings /></ProtectedRoute>} />
    <Route path="*" element={<Navigate to="/" replace />} />
  </Routes>
</BrowserRouter>
```

## Deep-Link Support

### How It Works

1. **User navigates to URL**: e.g., `https://jobs.sunrisepaint.in/candidates`
2. **Laravel receives request**: Fallback route matches (not an API route)
3. **Laravel serves index.html**: Returns the React app shell
4. **React Router takes over**: Client-side routing renders the correct component

### Supported Deep Links

All SPA routes support deep-linking:
- `/` - Dashboard
- `/candidates` - Candidate management
- `/resumes` - Resume management
- `/jobs` - Job discovery
- `/matches` - Job matches
- `/applications` - Applications tracking
- `/settings` - Settings

### Testing Deep Links

To verify deep-linking works:

1. Build the React app:
   ```bash
   cd frontend
   npm run build
   cd ..
   cp -r frontend/dist backend/public/app
   ```

2. Start Laravel:
   ```bash
   cd backend
   php artisan serve
   ```

3. Direct navigation tests:
   - Open `http://localhost:8000/candidates` (should load, not 404)
   - Open `http://localhost:8000/jobs` (should load, not 404)
   - Open `http://localhost:8000/settings` (should load, not 404)
   - Refresh each page (should stay on the same route)

4. API routes should NOT fallback to SPA:
   - `http://localhost:8000/api/user` (returns JSON, not HTML)
   - `http://localhost:8000/api/login` (accepts POST, returns JSON)

## API Base URL Configuration

**`frontend/src/lib/api.ts`**:
```typescript
const API_BASE_URL = import.meta.env.MODE === 'production'
  ? '/api'
  : (import.meta.env.VITE_API_URL || 'http://localhost:8000/api')
```

- **Production**: Uses relative `/api` (same-origin)
- **Development**: Uses absolute URL to Laravel backend (default: `http://localhost:8000/api`)
- Configurable via `VITE_API_URL` environment variable

**`frontend/.env.example`**:
```env
# API URL for development (production uses relative /api)
VITE_API_URL=http://localhost:8000/api
```

## Build Scripts

### Windows (`scripts/build-and-copy.ps1`)
```powershell
cd frontend
npm ci
npm run build
cd ..
Remove-Item backend\public\app -Recurse -Force
Copy-Item frontend\dist -Destination backend\public\app -Recurse
```

### Linux/Mac (`scripts/build-and-copy.sh`)
```bash
cd frontend
npm ci
npm run build
cd ..
rm -rf backend/public/app
cp -r frontend/dist backend/public/app
```

## Production Deployment on Hostinger

### Preferred Structure

1. **Git deployment directory**: `/home/<user>/jobs-platform`
2. **Subdomain document root**: `/home/<user>/jobs-platform/backend/public`
3. **React build location**: `/home/<user>/jobs-platform/backend/public/app`

In this structure:
- User visits `https://jobs.sunrisepaint.in/candidates`
- Request goes to Laravel's `public/index.php`
- Fallback route serves `public/app/index.html`
- React Router renders `/candidates` component

### Fallback Structure

If subdomain document root cannot be changed:

1. **Git deployment directory**: `/home/<user>/domains/jobs.sunrisepaint.in/public_html`
2. **Repository root**: Same as above
3. **Laravel app root**: `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend`
4. **Laravel public**: `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend/public`
5. **React build**: `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend/public/app`

Root `.htaccess` redirects requests to `backend/public/index.php`.

## Verification Checklist

- [x] React build output copied to `backend/public/app/`
- [x] Vite `base` configured to `/app/`
- [x] Laravel fallback route serves `index.html`
- [x] API routes excluded from fallback (`^(?!api).*`)
- [x] React Router configured with all routes
- [x] API base URL uses relative path in production
- [x] Build scripts updated with correct paths
- [x] `.gitignore` allows committing `backend/public/app/`
- [ ] Test: Direct navigation to `/candidates` works
- [ ] Test: Direct navigation to `/jobs` works
- [ ] Test: Direct navigation to `/settings` works
- [ ] Test: Page refresh preserves route
- [ ] Test: API routes return JSON (not HTML)

## Troubleshooting

### 404 on deep links

**Symptom**: Navigating directly to `/candidates` returns 404

**Solutions**:
1. Verify React build exists: `ls backend/public/app/index.html`
2. Check Laravel fallback route is present in `routes/web.php`
3. Ensure `.htaccess` redirects to Laravel's `index.php`
4. Verify `base: '/app/'` in `vite.config.ts`

### Assets not loading

**Symptom**: Page loads but CSS/JS files return 404

**Solutions**:
1. Check Vite `base` configuration matches deployment path
2. Verify build output is in correct directory
3. Check browser console for asset paths

### API routes returning HTML

**Symptom**: API calls return React app HTML instead of JSON

**Solutions**:
1. Verify fallback route excludes `/api`: `->where('any', '^(?!api).*')`
2. Check API routes are defined in `routes/api.php`
3. Ensure API calls use correct base URL

## References

- [React Router Documentation](https://reactrouter.com/)
- [Vite Base Configuration](https://vitejs.dev/config/shared-options.html#base)
- [Laravel SPA Deployment](https://laravel.com/docs/deployment)
