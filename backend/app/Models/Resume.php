<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Resume extends Model
{
    use HasFactory;

    protected $fillable = [
        'candidate_id',
        'file_path',
        'file_name',
        'file_type',
        'file_size',
        'parsed_data',
        'status',
    ];

    protected $casts = [
        'parsed_data' => 'array',
    ];

    public function candidate()
    {
        return $this->belongsTo(Candidate::class);
    }
}
