<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_listings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('company')->nullable();
            $table->string('location')->nullable();
            $table->string('job_type')->nullable(); // full-time, part-time, contract, etc.
            $table->string('salary_range')->nullable();
            $table->string('experience_level')->nullable(); // entry, mid, senior, etc.
            $table->json('requirements')->nullable();
            $table->json('skills')->nullable();
            $table->string('application_url')->nullable();
            $table->string('source')->nullable(); // where the job was found
            $table->string('status')->default('active'); // active, closed, draft
            $table->timestamp('posted_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            // Indexes for filtering
            $table->index('status');
            $table->index('job_type');
            $table->index('location');
            $table->index('posted_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_listings');
    }
};
