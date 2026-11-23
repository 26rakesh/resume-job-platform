<?php

return [

    'default' => env('QUEUE_CONNECTION', 'database'),

    'connections' => [
        'database' => [
            'driver' => 'database',
            'table' => env('QUEUE_TABLE', 'jobs'),
            'queue' => env('QUEUE_DEFAULT_QUEUE', 'default'),
            'retry_after' => 90,
            'after_commit' => false,
        ],
    ],
];
