<?php

namespace App\Http\Middleware;

use Illuminate\Auth\Middleware\Authenticate as Middleware;

class Authenticate extends Middleware
{
    protected function redirectTo($request)
    {
        // API requests must never redirect to a named login route —
        // login is handled by the React SPA. Returning null lets the
        // exception handler emit a 401 JSON response for /api/*.
        return $request->is('api/*') || $request->expectsJson() ? null : '/login';
    }
}
