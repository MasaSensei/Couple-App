<?php

namespace App\Jobs;

use App\Services\Ops\Heartbeat;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/** Dispatched every minute by the scheduler; proves a worker is consuming the queue. */
class QueueHeartbeat implements ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public int $timeout = 20;

    public function handle(Heartbeat $heartbeat): void
    {
        $heartbeat->beat('queue');
    }
}
