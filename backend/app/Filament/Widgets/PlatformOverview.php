<?php

namespace App\Filament\Widgets;

use App\Filament\BillingAccess;
use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\User;
use Filament\Support\Icons\Heroicon;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Number;

/** Who uses the product. Counts only: no names, no content. */
class PlatformOverview extends StatsOverviewWidget
{
    protected static ?int $sort = 0;

    protected ?string $heading = 'Platform';

    protected ?string $pollingInterval = '120s';

    public static function canView(): bool
    {
        return auth()->user()?->is_admin === true;
    }

    protected function getStats(): array
    {
        $weekAgo = now()->subDays(7);

        $users = User::query()->count();
        $newUsers = User::query()->where('created_at', '>=', $weekAgo)->count();

        $couples = Couple::query()->count();
        $complete = DB::table('couple_members')
            ->select('couple_id')
            ->groupBy('couple_id')
            ->havingRaw('count(*) >= 2')
            ->get()
            ->count();

        $stats = [
            Stat::make('Users', Number::format($users))
                ->description("+{$newUsers} in the last 7 days")
                ->descriptionIcon(Heroicon::OutlinedArrowTrendingUp)
                ->color($newUsers > 0 ? 'success' : 'gray'),
            Stat::make('Couples', Number::format($couples))
                ->description(Number::format($complete).' with both partners · '.Number::format($couples - $complete).' waiting')
                ->descriptionIcon(Heroicon::OutlinedUserGroup)
                ->color('gray'),
        ];

        // Billing numbers follow the billing permissions, like the billing screens.
        if (BillingAccess::can('billing.view')) {
            $byStatus = CoupleSubscription::query()
                ->selectRaw('status, count(*) as total')
                ->groupBy('status')
                ->pluck('total', 'status');

            $attention = (int) ($byStatus['grace_period'] ?? 0) + (int) ($byStatus['payment_failed'] ?? 0);

            $stats[] = Stat::make('Active subscriptions', Number::format((int) ($byStatus['active'] ?? 0)))
                ->description($attention > 0
                    ? "{$attention} need attention (grace period or payment failed)"
                    : Number::format((int) ($byStatus['cancelled'] ?? 0)).' cancelled, still in paid period')
                ->descriptionIcon(Heroicon::OutlinedCreditCard)
                ->color($attention > 0 ? 'warning' : 'success');
        }

        return $stats;
    }
}
