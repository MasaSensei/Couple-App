<?php

namespace App\Providers\Filament;

use App\Http\Middleware\RestrictAdminAccess;
use Filament\Auth\MultiFactor\App\AppAuthentication;
use Filament\FontProviders\LocalFontProvider;
use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\AuthenticateSession;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Navigation\NavigationGroup;
use Filament\Pages\Dashboard;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\HtmlString;
use Illuminate\View\Middleware\ShareErrorsFromSession;

class AdminPanelProvider extends PanelProvider
{
    /** Navigation groups, in sidebar order. Resources refer to these labels. */
    public const GROUP_OVERVIEW = 'Overview';

    public const GROUP_PEOPLE = 'People';

    public const GROUP_BILLING = 'Billing';

    public const GROUP_APPEARANCE = 'Content & appearance';

    public const GROUP_STORAGE = 'Storage & backups';

    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->login()
            // Admins manage their authenticator app from the profile page.
            ->profile()
            ->multiFactorAuthentication(
                [AppAuthentication::make()->recoverable()],
                isRequired: fn (): bool => (bool) config('security.admin.mfa_required'),
            )

            // Brand: same identity as the app, quieter voice. Fonts are
            // self-hosted (public/brand), so no admin page calls a font CDN.
            ->brandName('Our Little Space Admin')
            ->brandLogo(fn () => new HtmlString(
                '<span class="ols-brand">our little space'
                .'<svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><path d="M12 21C6 16.6 2.5 13.3 2.5 9.2 2.5 6.3 4.8 4 7.7 4c1.7 0 3.3.8 4.3 2.1C13 4.8 14.6 4 16.3 4c2.9 0 5.2 2.3 5.2 5.2 0 4.1-3.5 7.4-9.5 11.8z"/></svg>'
                .'<small>Admin</small></span>'
            ))
            ->brandLogoHeight('1.75rem')
            ->favicon(asset('brand/favicon.svg'))
            ->font('Nunito', url: asset('brand/brand.css'), provider: LocalFontProvider::class)
            ->colors([
                'primary' => Color::hex('#B4475F'),
                'gray' => Color::Stone,
                'success' => Color::hex('#3F7D5C'),
                'warning' => Color::Amber,
                'danger' => Color::hex('#B3394A'),
                'info' => Color::hex('#386A92'),
            ])

            ->sidebarCollapsibleOnDesktop()
            ->unsavedChangesAlerts()
            ->navigationGroups([
                NavigationGroup::make(self::GROUP_OVERVIEW),
                NavigationGroup::make(self::GROUP_PEOPLE),
                NavigationGroup::make(self::GROUP_BILLING),
                NavigationGroup::make(self::GROUP_APPEARANCE),
                NavigationGroup::make(self::GROUP_STORAGE),
            ])

            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\Filament\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\Filament\Pages')
            ->pages([
                Dashboard::class,
            ])
            // Dashboard widgets live in app/Filament/Widgets (real data only;
            // the Filament promo widget is not shown).
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\Filament\Widgets')
            ->middleware([
                RestrictAdminAccess::class,
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                AuthenticateSession::class,
                ShareErrorsFromSession::class,
                PreventRequestForgery::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,
            ])
            ->authGuard('web');
    }
}
