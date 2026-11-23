# Database Migrations Review

## Original Scope

The original project scope required the following tables:
1. **users** - User accounts and authentication
2. **candidates** - Candidate profiles
3. **resumes** - Resume files and parsed data

## Additional Migrations

The implementation includes two additional migrations:
4. **jobs** - Laravel queue jobs table
5. **cache** - Laravel cache table

## Migration Review

### 1. users (2024_01_01_000001_create_users_table.php)

```php
Schema::create('users', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('email')->unique();
    $table->timestamp('email_verified_at')->nullable();
    $table->string('password');
    $table->string('role')->default('user'); // Default to 'user', admin created via command
    $table->rememberToken();
    $table->timestamps();
});
```

**Review**:
- ✅ Primary key: `id()` (bigint, auto-increment)
- ✅ Unique constraint on `email`
- ✅ Default role is 'user' (not 'admin')
- ✅ Timestamps for audit trail
- ✅ Password field (hashed at application level)
- ✅ Standard Laravel user table structure

**Justification**: Required for authentication and role-based access control.

---

### 2. candidates (2024_01_01_000002_create_candidates_table.php)

```php
Schema::create('candidates', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->onDelete('cascade');
    $table->string('name');
    $table->string('email');
    $table->string('phone')->nullable();
    $table->string('location')->nullable();
    $table->json('skills')->nullable();
    $table->integer('experience_years')->nullable();
    $table->string('current_title')->nullable();
    $table->string('expected_salary')->nullable();
    $table->text('notes')->nullable();
    $table->timestamps();
});
```

**Review**:
- ✅ Primary key: `id()` (bigint, auto-increment)
- ✅ Foreign key: `user_id` → `users.id` with `onDelete('cascade')`
- ✅ Cascade delete: When a user is deleted, associated candidates are automatically deleted
- ✅ JSON column: `skills` (MySQL 5.7+ supports JSON type)
- ✅ Nullable fields for optional data
- ✅ Integer for `experience_years` (appropriate type)
- ✅ Text for `notes` (supports longer content)
- ✅ Timestamps for audit trail

**Justification**: Required for candidate profile management.

---

### 3. resumes (2024_01_01_000003_create_resumes_table.php)

```php
Schema::create('resumes', function (Blueprint $table) {
    $table->id();
    $table->foreignId('candidate_id')->constrained()->onDelete('cascade');
    $table->string('file_path');
    $table->string('file_name');
    $table->string('file_type');
    $table->integer('file_size');
    $table->json('parsed_data')->nullable();
    $table->string('status')->default('pending');
    $table->timestamps();
});
```

**Review**:
- ✅ Primary key: `id()` (bigint, auto-increment)
- ✅ Foreign key: `candidate_id` → `candidates.id` with `onDelete('cascade')`
- ✅ Cascade delete: When a candidate is deleted, associated resumes are automatically deleted
- ✅ JSON column: `parsed_data` (stores structured resume content)
- ✅ String for file metadata (path, name, type)
- ✅ Integer for `file_size` (bytes)
- ✅ Default status: 'pending'
- ✅ Timestamps for audit trail

**Missing**:
- ⚠️ No index on `status` (may be needed for filtering by status)
- ⚠️ No index on `candidate_id` (already indexed by foreign key constraint)
- ⚠️ No index on `file_type` (may be needed for filtering by file type)

**Justification**: Required for resume storage and management.

---

### 4. jobs (2024_01_01_000004_create_jobs_table.php)

```php
Schema::create('jobs', function (Blueprint $table) {
    $table->id();
    $table->string('queue')->index();
    $table->longText('payload');
    $table->unsignedTinyInteger('attempts');
    $table->unsignedInteger('reserved_at')->nullable();
    $table->unsignedInteger('available_at');
    $table->unsignedInteger('created_at');
});
```

**Review**:
- ✅ Primary key: `id()` (bigint, auto-increment)
- ✅ Index on `queue` (for queue filtering)
- ✅ `longText` for `payload` (supports large serialized data)
- ✅ Unsigned integers for timestamps and counters
- ⚠️ Custom timestamp columns (not using `timestamps()`)
- ⚠️ No `updated_at` column (jobs are immutable once created)

**Justification**: **REQUIRED** - This is the standard Laravel queue jobs table. The application uses `QUEUE_CONNECTION=database` for background job processing (e.g., AI job matching, resume parsing). Without this table, the queue system cannot function.

---

### 5. cache (2024_01_01_000005_create_cache_table.php)

```php
Schema::create('cache', function (Blueprint $table) {
    $table->string('key')->primary();
    $table->mediumText('value');
    $table->integer('expiration');
});

Schema::create('cache_locks', function (Blueprint $table) {
    $table->string('key')->primary();
    $table->string('owner');
    $table->integer('expiration');
});
```

**Review**:
- ✅ Primary key: `key` (string)
- ✅ `mediumText` for `value` (supports cached data)
- ✅ Integer for `expiration` (Unix timestamp)
- ✅ Separate `cache_locks` table for atomic locks
- ✅ Standard Laravel cache table structure

**Justification**: **REQUIRED** - This is the standard Laravel cache table. The application uses `CACHE_STORE=database` for caching API responses, job matching results, and other data. Without this table, the cache system cannot function.

---

## Migration Ordering

The migrations are correctly ordered:
1. `users` - Base table (no dependencies)
2. `candidates` - Depends on `users` (foreign key)
3. `resumes` - Depends on `candidates` (foreign key)
4. `jobs` - Independent (Laravel queue table)
5. `cache` - Independent (Laravel cache table)

✅ **Correct ordering** - Foreign key dependencies are satisfied.

---

## Foreign Key Constraints

| Table | Foreign Key | References | On Delete |
|-------|-------------|------------|-----------|
| candidates | user_id | users.id | CASCADE |
| resumes | candidate_id | candidates.id | CASCADE |

✅ **Correct cascade behavior** - Deleting a user deletes their candidates; deleting a candidate deletes their resumes.

---

## Indexes

| Table | Indexed Columns |
|-------|-----------------|
| users | email (unique) |
| candidates | user_id (via foreign key) |
| resumes | candidate_id (via foreign key) |
| jobs | queue |
| cache | key (primary) |
| cache_locks | key (primary) |

**Recommendations**:
- Consider adding index on `resumes.status` for filtering by status
- Consider adding index on `resumes.file_type` for filtering by file type

---

## JSON Compatibility with MySQL

All JSON columns are compatible with MySQL 5.7+:
- `candidates.skills` - JSON
- `resumes.parsed_data` - JSON

✅ **Compatible** - Hostinger's MySQL 8.0+ fully supports JSON columns.

---

## Column Types

| Column | Type | Justification |
|--------|------|---------------|
| users.role | string | Flexible for future role expansion |
| candidates.phone | string | Supports international formats |
| candidates.location | string | Flexible address format |
| candidates.skills | json | Structured skill data with querying |
| candidates.experience_years | integer | Numeric comparison |
| candidates.expected_salary | string | Flexible (range, currency, etc.) |
| candidates.notes | text | Longer content support |
| resumes.file_path | string | File system path |
| resumes.file_name | string | File name |
| resumes.file_type | string | MIME type or extension |
| resumes.file_size | integer | Bytes |
| resumes.parsed_data | json | Structured resume content |
| resumes.status | string | Status enum alternative |
| jobs.queue | string | Queue name |
| jobs.payload | longText | Serialized job data |
| jobs.attempts | unsignedTinyInteger | Small counter (0-255) |
| jobs.timestamps | unsignedInteger | Unix timestamps |

✅ **Appropriate types** - All column types are appropriate for their use cases.

---

## Summary

### Required Tables (Original Scope)
1. ✅ **users** - Authentication and authorization
2. ✅ **candidates** - Candidate profiles
3. ✅ **resumes** - Resume storage

### Additional Tables (Justified)
4. ✅ **jobs** - Laravel queue system (required for background job processing)
5. ✅ **cache** - Laravel cache system (required for caching)

### Migration Status
- ✅ All migrations follow Laravel conventions
- ✅ Foreign key constraints with cascade delete
- ✅ Correct migration ordering
- ✅ JSON columns compatible with MySQL
- ✅ Appropriate column types
- ⚠️ Optional: Add indexes on `resumes.status` and `resumes.file_type`

### Recommendations

1. **Add indexes** (optional, for performance):
   ```php
   $table->index('status'); // in resumes migration
   $table->index('file_type'); // in resumes migration
   ```

2. **Do not remove** `jobs` or `cache` tables - they are required for Laravel's queue and cache systems.

3. **Migration ordering is correct** - no changes needed.

4. **JSON columns are safe** - MySQL 8.0+ (Hostinger) fully supports JSON.

---

## Migration Commands

### Run migrations (development)
```bash
cd backend
php artisan migrate
```

### Run migrations (production)
```bash
cd backend
php artisan migrate --force
```

### Rollback migrations (development only)
```bash
cd backend
php artisan migrate:rollback
```

### Fresh migration (drops all tables, development only)
```bash
cd backend
php artisan migrate:fresh
```

---

## Production Deployment Notes

⚠️ **IMPORTANT**: Do not run migrations against production without:
1. Testing migrations in a staging environment first
2. Backing up the production database
3. Reviewing the migration changes
4. Having a rollback plan

The migrations in this codebase are safe to run on an empty database. For existing databases, ensure no data conflicts exist.
