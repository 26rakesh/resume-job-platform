# Resume Job Platform MVP — Technical Implementation Plan

Status: **PLAN ONLY — do not build until approved.**
Domain: https://jobs.sunrisepaint.in
Stack: Laravel (PHP) backend, React + Vite + Tailwind frontend (static build), MySQL, Gemini API (OpenAI-ready abstraction), separate Chrome extension.

---

## 1. Hosting compatibility (Hostinger Business shared hosting)

### PHP / Laravel version — VERIFIED 2026-11-23
- Hostinger PHP selected: **8.3** ✓ (within Laravel 13's supported range of 8.3–8.5).
- **Laravel 13** released 2026-03-17; bug fixes until Q3 2027, security fixes until 2028-03-17. Requires PHP >= 8.3 → **compatible**.
- Laravel 13 required extensions: ctype, curl, dom, filter, hash, mbstring, openssl, pcre, PDO, session, tokenizer, xml.
- Hostinger-confirmed enabled: PDO, nd_pdo_mysql, mysqli, mbstring, fileinfo, intl, gd, zip, bcmath, xmlreader, xmlwriter.
- **Still to verify via phpinfo**: curl, openssl, dom, tokenizer, ctype, filter, hash, session, phar (usually built-in, but curl/openssl are the critical ones for Gemini API + HTTPS).
- Resume-processing extras all covered: zip (docx), gd (images), fileinfo (MIME validation), intl, xmlreader/writer.

### Required PHP extensions
Laravel 11 minimums: `pdo_mysql`, `mbstring`, `openssl`, `tokenizer`, `xml`, `ctype`, `json`, `bcmath`, `fileinfo`, `curl`.
Resume processing additions: `gd` or `imagick` (PDF preview), `zip` (docx parsing), `dom`/`libxml` (XML inside docx), `fileinfo` for upload MIME validation, `curl` for Gemini calls.
Hostinger enables most of these by default; verify `phpinfo()` / `php -m` after provisioning.

### Deployment limitations & mitigations
| Concern | Limitation | Mitigation |
|---|---|---|
| Composer | Not installed on shared hosting by default; may be runnable via SSH (Business plan includes SSH) | Verify SSH + `composer` on server; else build `vendor/` locally and upload, or check if Hostinger Git deploy runs `composer install` (verify in hPanel → Git). |
| Node.js | No persistent Node server on shared hosting | **Confirmed feasible**: `vite build` locally → static assets copied into Laravel `public/`; zero Node in production. |
| Cron Jobs | hPanel cron, min interval ~15 min typical | All scheduled work via `php artisan schedule:run` triggered by ONE cron entry every 15 min; Laravel scheduler fans out jobs. |
| PHP execution time | `max_execution_time` often 30–120s, `memory_limit` 256–512MB | Keep requests short; never do AI calls inline during a web request — dispatch to queue-ish pattern via DB `jobs` table processed by cron (`queue:work --stop-when-empty`). |
| File uploads | `upload_max_filesize`/`post_max_size` commonly 32–64MB | Resume files capped at ~10MB app-side; validate MIME + extension server-side. |
| MySQL | Single DB per user typical | Use one DB + prefixed tables; no Redis, no Horizon. |
| Storage/permissions | Docroot is `public_html`; app must live outside it | **Recommended layout**: Laravel project at `/home/<user>/jobs-app/` (outside `public_html`); subdomain `jobs.sunrisepaint.in` docroot pointed at `jobs-app/public` via hPanel. Fallback if docroot can't change: tiny shim `index.php`/`.htaccess` inside `public_html` that bootstraps `jobs-app/public/index.php`. `.env`, `vendor/`, `storage/`, `app/` all stay outside docroot. |

### Hostinger directory structure (recommended)
```
/home/<user>/
├── public_html/                  # main domain (untouched)
└── jobs-app/                     # Laravel project root — NOT web-accessible
    ├── app/  bootstrap/  config/  database/  routes/
    ├── vendor/                   # uploaded or composer-installed via SSH
    ├── storage/                  # logs, framework cache, private resumes
    ├── .env                      # secrets — outside docroot
    └── public/                   # ONLY this is exposed
        ├── index.php
        ├── .htaccess
        └── app/                  # React build output (vite build)
```
Subdomain docroot: `/home/<user>/jobs-app/public` (set in hPanel when creating/managing the subdomain).
| Queue workers | No long-running daemon | **Database queue driver + cron `queue:work --stop-when-empty --max-time=55` every 5–15 min.** Sufficient at 100-candidate scale. |

---

## 2. Architecture

```
Browser (React SPA, static build)
   │  HTTPS, Sanctum token auth
   ▼
Laravel API (jobs.sunrisepaint.in/api)
   ├── Resume upload → validate → store private → DB job record
   ├── Queue processor (cron) → parse PDF/DOCX → Gemini extract → profile
   ├── Job matcher → Gemini/OpenAI structured matching → scores
   ├── MySQL (users, profiles, resumes, jobs, matches, applications, audit_log)
   └── Cron (schedule:run every 15 min → scheduled match-refresh, queue drain)

Chrome Extension (separate project, Manifest V3)
   └── Reads approved applications via API → fills job forms → PAUSES for human approval → submits
```

Key decisions:
- **React is a static build** (`npm run build`) output copied into Laravel's `public/` — zero Node runtime in production.
- **No Redis, no Horizon, no daemon.** `QUEUE_CONNECTION=database`, drained by cron.
- **AI behind an interface**: `AiProviderInterface` → `GeminiProvider` now, `OpenAiProvider` later. Structured output (JSON schema) for resume parsing and match scoring.
- **Extension never auto-submits.** It pre-fills, shows a preview, requires explicit click. Application final state recorded via API.
- Hostinger serves everything over HTTPS on the same domain — extension uses the same API with token auth.

---

## 3. Repository structure (monorepo)

```
jobs-platform/
├── backend/                  # Laravel 11 app (deployed to Hostinger)
│   ├── app/
│   │   ├── Http/Controllers/Api/V1/   # ResumeController, JobController,
│   │   │                              # MatchController, ApplicationController, AuthController
│   │   ├── Models/                     # User, Resume, CandidateProfile, Job, JobMatch,
│   │   │                              # Application, AuditLog
│   │   ├── Services/
│   │   │   ├── Ai/AiProviderInterface.php
│   │   │   ├── Ai/GeminiProvider.php
│   │   │   ├── Ai/OpenAiProvider.php   # stub for later
│   │   │   ├── ResumeParser.php        # text extraction (pdf/docx)
│   │   │   └── JobMatcher.php
│   │   ├── Jobs/                        # ProcessResume, GenerateMatches, FetchJobs, SendApplication
│   │   └── Policies/                    # authorization per model
│   ├── database/migrations/             # all schema
│   ├── database/seeders/                # roles, sample jobs, dev users
│   ├── routes/api.php, web.php
│   ├── storage/app/private/resumes/     # NOT web-accessible
│   └── .env.example                      # all keys documented, no secrets
├── frontend/                 # React + Vite + Tailwind (build → backend/public/app)
│   └── src/{pages,components,hooks,api,lib}
├── extension/                # Chrome MV3 extension (TypeScript)
│   └── src/{background,content,popup,shared}
├── docs/
│   ├── ARCHITECTURE.md       # this plan, finalized
│   ├── DEPLOYMENT.md         # Hostinger step-by-step
│   ├── API.md                # endpoint reference
│   └── SECURITY.md
├── scripts/
│   ├── deploy.ps1 / deploy.sh           # build + rsync/FTP upload
│   └── cron.example                     # crontab lines for hPanel
├── .gitignore                # .env, vendor, node_modules, *.pdf resumes, build artifacts
└── README.md
```

---

## 4. Security plan

- **Auth**: Laravel Sanctum SPA/token auth; tokens stored in `personal_access_tokens`; refresh/expiry policy; optional email verification.
- **RBAC readiness**: Spatie `laravel-permission` or a simple `roles` table (admin / candidate / viewer) — wire `Gate`/`Policy` now, even with 1 role.
- **Private resumes**: stored in `storage/app/private`; only streamed via `ResumesController@download` with ownership check. Never in `public/`.
- **API keys**: `GEMINI_API_KEY`, `OPENAI_API_KEY` in `.env` only; `.env` outside deployable public path; `.env.example` committed without values. Server-side only — extension and React never see AI keys.
- **File validation**: server-side MIME sniffing (`finfo`), extension whitelist `pdf|docx`, 10MB cap, virus-scan note (ClamAV unavailable on shared hosting → document as accepted risk + magic-byte check).
- **Candidate data**: encryption at rest optional (`encrypted` cast for sensitive fields); data-export and delete-account endpoints for DPDP/GDPR readiness.
- **Audit logging**: `audit_logs` table (who/what/when/IP) for logins, resume access, application submissions.
- **CSRF**: Sanctum stateful SPA gets CSRF via `/sanctum/csrf-cookie`; cookie-based auth only same-site.
- **Rate limiting**: `throttle` middleware on auth, upload, and AI-heavy endpoints (e.g. `throttle:10,1` uploads; `throttle:60,1` API).
- **Transport**: HTTPS enforced, HSTS header, secure cookie flags.

---

## 5. Development milestones (MVP)

1. **M0 — Scaffold**: Laravel app in `backend/`, Vite React in `frontend/`, monorepo layout, `.env.example`, gitignore, CI-less local setup docs.
2. **M1 — Auth + profiles**: Sanctum login/register, candidate profile model, role scaffolding.
3. **M2 — Resume pipeline**: upload → validation → private storage → DB queue job → PDF/DOCX text extraction → Gemini structured parse → `candidate_profiles`. Verify on 3 sample resumes (no real candidate data in repo — use fixtures/synthetic).
4. **M3 — Job discovery**: `jobs` table + manual/CSV/seed import first (Gemini-assisted fetch or curated feed later — decide scope).
5. **M4 — Matching**: `JobMatcher` service → Gemini prompt → match score + rationale stored in `job_matches`; UI list.
6. **M5 — Applications + extension**: application tracker, Chrome extension pre-fill + human-approval flow.
7. **M6 — Hardening**: audit log UI, rate limits, tests (PHPUnit feature tests for API), deploy docs, staging dry-run on Hostinger.

---

## 6. Risks & limitations

- **Shared hosting ceilings**: concurrent Gemini calls must be serialized via cron — matching 100 candidates × N jobs may take hours; batch and throttle. Fine for MVP, not for real-time UX.
- **No queue daemon**: if cron granularity is 15 min, worst-case latency ~15 min for resume processing. Acceptable for MVP; note in UX copy.
- **Hostinger Git deploy**: confirm whether it runs `composer install`/`npm build` on push — if not, deploy = build locally + upload `vendor/` + `public/app/`.
- **PDF parsing quality**: scanned/image PDFs need OCR — Gemini can accept PDF bytes directly, but large files risk token/size limits; cap at 10MB and document fallback (user re-uploads or text paste).
- **Job board scraping/ToS**: extension-assisted applications may violate some boards' ToS — keep human-in-the-loop and per-site testing.
- **Gemini rate limits/quota**: batch jobs, exponential backoff, provider abstraction allows failover.
- **`max_execution_time`**: keep every artisan command under ~50s or chunk work.

---

## 7. Confirmed decisions

- **Repo**: existing GitHub repo — URL to be provided; will clone into this workspace.
- **User model**: staffing agency / admin manages a pool of ~100 candidate resumes (single-tenant admin + candidate records, not self-serve job seekers).
- **Job sources**: undecided — MVP defaults to **manual entry + CSV import**; feed/scraper adapters designed behind an interface so they can be added later.
- **Deploy**: Hostinger Git auto-deploy confirmed, GitHub `main` → deployment dir is `public_html` of jobs.sunrisepaint.in (client-approved). Security mitigated via root `.htaccess` denying access to app/, vendor/, .env, storage/. Hostinger Git does NOT run composer/npm — full build happens locally/CI, artifacts committed or installed via SSH. Full workflow: `docs/DEPLOYMENT.md`. Note: For client domain deployments, recommend standard pattern (deploy outside `public_html`, docroot to Laravel's `public/`). Pending: SSH credentials + MySQL DB name/user.

## 8. Still needed before implementation

1. GitHub repo URL.
2. Hostinger specifics: PHP version selector (target 8.3), docroot location for the app (subdirectory/subdomain of jobs.sunrisepaint.in?), hPanel cron minimum interval.
3. Gemini API key (added to `.env` only, never committed).
4. Hostinger plan tier (affects cron frequency and PHP limits).
5. Extension target sites for MVP (recommend starting with one lower-risk board; LinkedIn/Naukri actively block automation).
