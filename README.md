# Resume Job Platform

AI-powered Resume Parsing, Job Discovery, Candidate Matching and Application Management Platform.

## Tech Stack

- **Backend**: Laravel 13 (PHP 8.3)
- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS
- **Database**: MySQL
- **AI**: Gemini API (extensible to OpenAI)
- **Auth**: Laravel Sanctum
- **Hosting**: Hostinger Business Shared Hosting

## Project Structure

```
jobs-platform/
├── backend/              # Laravel application
│   ├── app/              # Application logic
│   ├── config/           # Configuration files
│   ├── database/         # Migrations and seeders
│   ├── public/           # Public files (web root)
│   ├── routes/           # API and web routes
│   └── storage/          # File storage (private resumes)
├── frontend/             # React + Vite application
│   ├── src/              # React components and pages
│   └── dist/             # Build output (copied to backend/public/app)
├── extension/            # Chrome extension (future)
├── docs/                 # Documentation
└── scripts/              # Build and deployment scripts
```

## Local Development

### Prerequisites

- PHP 8.3 with extensions: ctype, curl, dom, fileinfo, mbstring, openssl, pdo_mysql, tokenizer, xml
- Composer
- Node.js 20+
- MySQL 8.0+

### Backend Setup

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

The frontend dev server runs on `http://localhost:3000` with API proxy to `http://localhost:8000`.

### Testing Checklist

- [ ] Laravel boots successfully: `php artisan` should list available commands
- [ ] React builds successfully: `npm run build` in `frontend/` should complete without errors
- [ ] Frontend routes work: navigate to `http://localhost:3000` and check all pages
- [ ] Backend API responds: test `POST /api/login` and `GET /api/user` with auth
- [ ] MySQL connection works: ensure migrations run successfully
- [ ] Authentication flow works: login/register/logout cycle completes
- [ ] Production build generates correct static assets: run build script and verify `backend/public/app/` contents

**Note**: The foundation code was created without local testing due to environment limitations (PHP missing OpenSSL, Composer not available locally). Please run the above checklist on a properly configured development environment before proceeding.

### Build for Production

```bash
# Windows
.\scripts\build-and-copy.ps1

# Linux/Mac
chmod +x scripts/build-and-copy.sh
./scripts/build-and-copy.sh
```

This builds the React app and copies `frontend/dist` to `backend/public/app`.

## Deployment to Hostinger

### Pre-deployment Checklist

1. Run the build script locally to generate static assets
2. Ensure `.env` is configured on the server (never commit `.env`)
3. SSH into Hostinger and run:
   ```bash
   cd ~/domains/jobs.sunrisepaint.in/public_html
   composer install --no-dev --optimize-autoloader
   php artisan migrate --force
   php artisan config:cache && php artisan route:cache && php artisan view:cache
   chmod -R 775 storage bootstrap/cache
   ```
4. Add cron job in hPanel:
   ```
   */15 * * * * cd ~/domains/jobs.sunrisepaint.in/public_html && php artisan schedule:run >> /dev/null 2>&1
   ```

### Security Notes

- `.htaccess` in the root denies access to sensitive directories (app/, vendor/, .env, storage/)
- Resumes are stored in `storage/app/private` — not web-accessible
- Never commit `.env` or real candidate resumes
- Use strong passwords and enable HTTPS

## API Endpoints

### Authentication
- `POST /api/login` - User login
- `POST /api/register` - User registration
- `POST /api/logout` - User logout (requires auth)
- `GET /api/user` - Get current user (requires auth)

### Other endpoints (to be implemented)
- Candidates CRUD
- Resume upload and parsing
- Job discovery
- Job matching
- Application tracking

## Environment Variables

See `backend/.env.example` for required variables:
- `APP_KEY` - Laravel application key
- `DB_*` - Database configuration
- `GEMINI_API_KEY` - Gemini API key for AI features
- `QUEUE_CONNECTION=database` - Queue driver (no Redis required)

## Development Workflow

1. Create feature branch from `main`
2. Make changes
3. Run build script before committing
4. Push and create pull request
5. Do not push directly to `main`
6. Approval required before merging to `main`

## License

Proprietary
