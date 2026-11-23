<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JobListing extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'description',
        'company',
        'location',
        'job_type',
        'salary_range',
        'experience_level',
        'requirements',
        'skills',
        'application_url',
        'source',
        'status',
        'posted_at',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'requirements' => 'array',
            'skills' => 'array',
            'posted_at' => 'datetime',
            'expires_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isActive(): bool
    {
        return $this->status === 'active' &&
               (!$this->expires_at || $this->expires_at->isFuture());
    }
}
