<?php

return [

    'default' => env('CACHE_STORE', 'database'),

    'stores' => [
        'database' => [
            'driver' => 'database',
            'table' => env('CACHE_TABLE', 'cache'),
            'connection' => null,
            'lock_connection' => null,
        ],
    ],
];
