<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default filesystem disk that should be used
    | by the framework. The "local" disk, as well as a variety of cloud
    | based disks are available to your application for file storage.
    |
    */

    'default' => env('FILESYSTEM_DISK', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Below you may configure as many filesystem disks as necessary, and you
    | may even configure multiple disks for the same driver. Examples for
    | most supported storage drivers are configured here for reference.
    |
    | Supported drivers: "local", "ftp", "sftp", "s3"
    |
    */

    'disks' => [

        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => true,
            'throw' => false,
            'report' => false,
        ],

        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => rtrim(env('APP_URL', 'http://localhost'), '/').'/storage',
            'visibility' => 'public',
            'throw' => false,
            'report' => false,
        ],

        's3' => [
            'driver' => 's3',
            'key' => env('AWS_ACCESS_KEY_ID'),
            'secret' => env('AWS_SECRET_ACCESS_KEY'),
            'region' => env('AWS_DEFAULT_REGION'),
            'bucket' => env('AWS_BUCKET'),
            'url' => env('AWS_URL'),
            'endpoint' => env('AWS_ENDPOINT'),
            'use_path_style_endpoint' => env('AWS_USE_PATH_STYLE_ENDPOINT', false),
            'throw' => false,
            'report' => false,
        ],

        /*
         * Encrypted photo ciphertext. Primary and backup must use separate
         * credentials (ideally separate providers/accounts). 'throw' is on so
         * storage failures surface as exceptions instead of silent false.
         */
        'photos_primary' => [
            'driver' => 's3',
            'key' => env('PHOTOS_PRIMARY_ACCESS_KEY'),
            'secret' => env('PHOTOS_PRIMARY_SECRET_KEY'),
            'region' => env('PHOTOS_PRIMARY_REGION', 'us-east-1'),
            'bucket' => env('PHOTOS_PRIMARY_BUCKET'),
            'endpoint' => env('PHOTOS_PRIMARY_ENDPOINT'),
            'use_path_style_endpoint' => env('PHOTOS_PRIMARY_PATH_STYLE', false),
            'visibility' => 'private',
            'throw' => true,
            'report' => false,
        ],

        'photos_backup' => [
            'driver' => 's3',
            'key' => env('PHOTOS_BACKUP_ACCESS_KEY'),
            'secret' => env('PHOTOS_BACKUP_SECRET_KEY'),
            'region' => env('PHOTOS_BACKUP_REGION', 'us-east-1'),
            'bucket' => env('PHOTOS_BACKUP_BUCKET'),
            'endpoint' => env('PHOTOS_BACKUP_ENDPOINT'),
            'use_path_style_endpoint' => env('PHOTOS_BACKUP_PATH_STYLE', false),
            'visibility' => 'private',
            'throw' => true,
            'report' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Here you may configure the symbolic links that will be created when the
    | `storage:link` Artisan command is executed. The array keys should be
    | the locations of the links and the values should be their targets.
    |
    */

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],

];
