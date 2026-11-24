<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_with_valid_credentials()
    {
        $user = User::factory()->create([
            'email' => 'test@example.com',
            'password' => bcrypt('password123'),
        ]);

        $response = $this->withHeader('referer', 'http://localhost')
            ->postJson('/api/login', [
                'email' => 'test@example.com',
                'password' => 'password123',
            ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['user', 'message']);
    }

    public function test_login_with_invalid_credentials()
    {
        $response = $this->postJson('/api/login', [
            'email' => 'invalid@example.com',
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(422);
    }

    public function test_login_rate_limiting()
    {
        // Attempt 6 logins in quick succession (limit is 5 per minute)
        for ($i = 0; $i < 6; $i++) {
            $this->postJson('/api/login', [
                'email' => 'test@example.com',
                'password' => 'wrongpassword',
            ]);
        }

        $response = $this->postJson('/api/login', [
            'email' => 'test@example.com',
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(429); // Too Many Requests
    }

    public function test_registration_disabled_in_production()
    {
        // This test should be run with APP_ENV=production
        config(['app.env' => 'production']);

        $response = $this->postJson('/api/register', [
            'name' => 'Test User',
            'email' => 'new@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(403)
            ->assertJson(['message' => 'Registration is disabled in production']);
    }

    public function test_protected_route_requires_authentication()
    {
        $response = $this->getJson('/api/user');

        $response->assertStatus(401);
    }

    public function test_unauthenticated_api_request_without_json_accept_returns_401()
    {
        // Browser-style request (Accept: text/html) must NOT redirect to a
        // named 'login' route — that caused "Route [login] not defined" 500s.
        $response = $this->get('/api/user');

        $response->assertStatus(401)
            ->assertJson(['message' => 'Unauthenticated.']);
    }

    public function test_authenticated_user_can_access_protected_route()
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user)->getJson('/api/user');

        $response->assertStatus(200)
            ->assertJson(['user' => ['id' => $user->id]]);
    }

    public function test_logout_invalidates_session()
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->withHeader('referer', 'http://localhost')
            ->postJson('/api/logout')
            ->assertStatus(200);

        // Attempt to access protected route after logout
        $this->getJson('/api/user')
            ->assertStatus(401);
    }
}
