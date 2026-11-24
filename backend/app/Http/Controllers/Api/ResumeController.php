<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Candidate;
use App\Models\Resume;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ResumeController extends Controller
{
    /**
     * List resumes for the authenticated user's candidate profile.
     */
    public function index(Request $request)
    {
        $candidate = $this->candidateFor($request->user());

        if (! $candidate) {
            return response()->json(['resumes' => []]);
        }

        return response()->json([
            'resumes' => $candidate->resumes()->latest()->get()->map(fn (Resume $r) => [
                'id' => $r->id,
                'file_name' => $r->file_name,
                'file_type' => $r->file_type,
                'file_size' => $r->file_size,
                'status' => $r->status,
                'created_at' => $r->created_at,
            ]),
        ]);
    }

    /**
     * Upload a resume file to private storage.
     */
    public function store(Request $request)
    {
        $request->validate([
            'resume' => 'required|file|mimes:pdf,doc,docx|max:10240',
        ]);

        $user = $request->user();
        $candidate = $this->candidateFor($user);

        if (! $candidate) {
            $candidate = Candidate::create([
                'user_id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ]);
        }

        $file = $request->file('resume');
        $path = $file->store('resumes', 'private'); // storage/app/private/resumes

        $resume = Resume::create([
            'candidate_id' => $candidate->id,
            'file_path' => $path,
            'file_name' => $file->getClientOriginalName(),
            'file_type' => $file->getClientOriginalExtension(),
            'file_size' => $file->getSize(),
            'status' => 'uploaded',
        ]);

        return response()->json([
            'resume' => [
                'id' => $resume->id,
                'file_name' => $resume->file_name,
                'file_type' => $resume->file_type,
                'file_size' => $resume->file_size,
                'status' => $resume->status,
            ],
            'message' => 'Resume uploaded successfully',
        ], 201);
    }

    /**
     * Download a resume — owner only.
     */
    public function download(Request $request, Resume $resume): StreamedResponse
    {
        $candidate = $this->candidateFor($request->user());
        abort_unless($candidate && $resume->candidate_id === $candidate->id, 403);
        abort_unless(Storage::disk('private')->exists($resume->file_path), 404);

        return Storage::disk('private')->download($resume->file_path, $resume->file_name);
    }

    private function candidateFor($user): ?Candidate
    {
        return Candidate::where('user_id', $user->id)->first();
    }
}
