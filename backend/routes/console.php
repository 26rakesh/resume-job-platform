<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

// Register custom commands
Artisan::command('admin:create', \App\Console\Commands\CreateAdmin::class)
    ->describe('Create an admin user securely');
