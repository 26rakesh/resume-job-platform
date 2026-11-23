<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class CreateAdmin extends Command
{
    protected $signature = 'admin:create';
    protected $description = 'Create an admin user securely (production-safe)';

    public function handle()
    {
        $this->info('Create Admin User');
        $this->warn('This command creates an admin user with full privileges.');

        $name = $this->ask('Enter admin name');
        $email = $this->ask('Enter admin email');

        // Validate email
        $validator = Validator::make(['email' => $email], [
            'email' => 'required|email|unique:users,email',
        ]);

        if ($validator->fails()) {
            $this->error('Invalid email or email already exists.');
            return 1;
        }

        $password = $this->secret('Enter password (min 8 characters)');
        $confirmPassword = $this->secret('Confirm password');

        if (strlen($password) < 8) {
            $this->error('Password must be at least 8 characters.');
            return 1;
        }

        if ($password !== $confirmPassword) {
            $this->error('Passwords do not match.');
            return 1;
        }

        // Create admin user
        $user = User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make($password),
            'role' => 'admin',
        ]);

        $this->info('Admin user created successfully!');
        $this->table(
            ['Name', 'Email', 'Role'],
            [[$user->name, $user->email, $user->role]]
        );

        return 0;
    }
}
