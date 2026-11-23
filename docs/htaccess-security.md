# Security .htaccess for Hostinger public_html deployment

Place this `.htaccess` in the root of the Laravel project (in `public_html` for jobs.sunrisepaint.in).

## Purpose

Deny web access to sensitive directories and files when deploying Laravel directly
to the web root (non-standard deployment). This is a mitigation — the standard
pattern is to deploy outside `public_html` and point the document root to
Laravel's `public/` folder.

## .htaccess content

```apache
<IfModule mod_rewrite.c>
    RewriteEngine On

    # Deny access to sensitive directories
    RewriteRule ^app/ - [F,L]
    RewriteRule ^bootstrap/ - [F,L]
    RewriteRule ^config/ - [F,L]
    RewriteRule ^database/ - [F,L]
    RewriteRule ^routes/ - [F,L]
    RewriteRule ^vendor/ - [F,L]
    RewriteRule ^storage/ - [F,L]

    # Deny access to sensitive files
    RewriteRule ^.env$ - [F,L]
    RewriteRule ^.env.*$ - [F,L]
    RewriteRule ^artisan$ - [F,L]
    RewriteRule ^composer.json$ - [F,L]
    RewriteRule ^composer.lock$ - [F,L]
    RewriteRule ^package.json$ - [F,L]
    RewriteRule ^package-lock.json$ - [F,L]
    RewriteRule ^phpunit.xml$ - [F,L]
    RewriteRule ^README.md$ - [F,L]

    # Allow Laravel's public routes
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^ index.php [L]
</IfModule>

# Deny direct access to specific files by type
<FilesMatch "^\.env|artisan|composer\.(json|lock)|package(-lock)?\.json|phpunit\.xml">
    Order allow,deny
    Deny from all
</FilesMatch>

# Deny directory listing
Options -Indexes
```

## Laravel's public/.htaccess

Laravel's `public/.htaccess` remains standard (no changes needed) — it handles
app routing. The root `.htaccess` above is the gatekeeper.

## Limitations

- This is a mitigation, not a replacement for proper directory isolation.
- If `.htaccess` is disabled or misconfigured on the server, sensitive files remain
  exposed.
- For client domain deployments, use the standard pattern (deployment outside
  `public_html`, document root pointing to Laravel's `public/`).
