# Task 1G — GitHub Actions CI Failure Diagnosis and Fix

**Date**: 2026-11-23 | **Branch**: `feature/mvp-foundation` | **Final commit**: `44a7459`

## Root causes (verified, in order of failure)

1. **`composer install` failed** — `backend/bootstrap/cache/` and `backend/storage/framework/*` were never committed (empty dirs aren't tracked). `post-autoload-dump` → `artisan package:discover` requires `bootstrap/cache`. Fixed by adding the standard Laravel `.gitignore` placeholders the root `.gitignore` already whitelisted. Commit `90e1b58`.

2. **`php artisan test --verbose` failed** — PHPUnit 12 removed `--verbose`; artisan exited "Unknown option" before running tests. Verified locally with CI-equivalent `.env`: `php artisan test --verbose` errors, `php artisan test` passes 7/7. Fixed by dropping the flag. Commit `44a7459`.

Note: GitHub job logs required repo-admin auth (API 403), so diagnosis was done by reproducing each CI step locally and bisecting failing steps via the Actions jobs API (step names/conclusions are public).

## Intermediate fixes (also required)
- `cd3f473`: added `pdo_sqlite`, `sqlite3`, `intl`, `gd` to setup-php extensions (phpunit.xml uses sqlite `:memory:`).
- `a2fba67`: removed empty `tests/Unit` suite from phpunit.xml (empty dirs not committed → PHPUnit "Test directory not found").

## Final CI results — ALL GREEN

Push run: https://github.com/26rakesh/resume-job-platform/actions/runs/45233195172 — **success**
PR run:   https://github.com/26rakesh/resume-job-platform/actions/runs/45233210376 — **success**

backend-tests (both events): composer install, .env, key:generate, MySQL migrations, `php artisan test` (7 passed), composer validate, PHP lint — all success.
frontend-tests (both events): npm ci, tsc, eslint, vite build, artifact upload — all success.

## Files changed
- `.github/workflows/ci.yml` (extensions, test command)
- `backend/phpunit.xml` (removed Unit suite)
- `backend/bootstrap/cache/.gitignore`, `backend/storage/**/.gitignore` (new placeholders)

## Status
- PR #1 open: https://github.com/26rakesh/resume-job-platform/pull/1 — **not merged**
- No Hostinger deployment. Awaiting explicit approval.
