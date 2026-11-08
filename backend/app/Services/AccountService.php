<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\CoupleSubscription;
use App\Models\Date;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

/**
 * Account deletion and personal data export (App Store 5.1.1(v), Google Play
 * account deletion policy, GDPR access/erasure). Policy and its reasoning:
 * docs/operations/account-deletion.md.
 */
class AccountService
{
    /**
     * Delete the user's account.
     *
     * - Personal data goes immediately: profile, sessions, devices, key
     *   packages, recovery package, own comments, purchase intents.
     * - Content of the shared space (memories, photos, dates) stays with the
     *   partner when one remains; authorship becomes anonymous (NULL).
     * - When the user is the last member, memories and photos move to the
     *   trash and the existing retention purge removes both stored copies
     *   (trash + backup retention). Dates are deleted.
     *
     * @return array{couple: 'none'|'kept_by_partner'|'dissolved'}
     */
    public function delete(User $user, string $password): array
    {
        if (! Hash::check($password, $user->password)) {
            throw ValidationException::withMessages(['password' => ['The password is incorrect.']]);
        }

        $membership = CoupleMember::where('user_id', $user->id)->first();
        $couple = $membership?->couple;
        $lastMember = $couple !== null && CoupleMember::where('couple_id', $couple->id)->count() === 1;

        if ($lastMember && $this->hasRenewingStoreSubscription($couple)) {
            // The store keeps charging until auto-renew is turned off there; we cannot do it for the user.
            throw new DomainException('Turn off auto-renew for your subscription first (Manage subscription), then delete your account.');
        }

        $result = DB::transaction(function () use ($user, $couple, $lastMember): array {
            $outcome = 'none';

            if ($couple !== null) {
                $outcome = $lastMember ? 'dissolved' : 'kept_by_partner';

                if ($lastMember) {
                    $this->dissolve($couple, $user);
                }
            }

            $user->tokens()->delete();
            DB::table('sessions')->where('user_id', $user->id)->delete();
            DB::table('password_reset_tokens')->where('email', $user->email)->delete();

            // FKs do the rest: devices, key packages, recovery package, comments,
            // membership, invitations and intents cascade; memories, photos,
            // dates, subscriptions and audit rows keep the row with NULL author.
            $user->delete();

            return ['couple' => $outcome];
        });

        Log::notice('account.deleted', ['user_id' => $user->id, 'couple_outcome' => $result['couple']]);

        return $result;
    }

    /** Machine-readable copy of the user's data. Photo bytes stay encrypted; the app exports them decrypted. */
    public function export(User $user): array
    {
        $couple = CoupleMember::where('user_id', $user->id)->first()?->couple;

        return [
            'exported_at' => now()->toIso8601String(),
            'format_version' => 1,
            'user' => $user->only(['id', 'name', 'email', 'created_at', 'updated_at']),
            'devices' => $user->devices()->get(['id', 'device_name', 'platform', 'created_at', 'last_seen_at', 'revoked_at']),
            'couple' => $couple === null ? null : [
                'id' => $couple->id,
                'relationship_started_at' => $couple->relationship_started_at?->format('Y-m-d'),
                'created_at' => $couple->created_at,
                'members' => $couple->members()->with('user:id,name')->get()->map(fn ($member) => [
                    'user_id' => $member->user_id,
                    'name' => $member->user?->name,
                    'joined_at' => $member->created_at,
                ]),
                'dates' => Date::where('couple_id', $couple->id)->orderBy('scheduled_at')
                    ->get(['id', 'created_by', 'title', 'description', 'location', 'scheduled_at', 'status', 'completed_at', 'created_at']),
                'memories' => Memory::where('couple_id', $couple->id)->orderBy('created_at')->get()->map(fn (Memory $memory) => [
                    ...$memory->only(['id', 'created_by', 'title', 'description', 'memory_date', 'location_name', 'location_address', 'latitude', 'longitude', 'created_at']),
                    'photos' => MemoryPhoto::where('memory_id', $memory->id)->where('status', 'verified')
                        ->get(['id', 'uploaded_by', 'mime_type', 'encrypted_size', 'created_at'])
                        ->map(fn (MemoryPhoto $photo) => [...$photo->toArray(), 'content_url' => "/api/v1/memory-photos/{$photo->id}/content"]),
                ]),
            ],
            'my_comments' => [
                'dates' => DB::table('date_comments')->where('user_id', $user->id)->get(['date_id', 'content', 'created_at']),
                'memories' => DB::table('memory_comments')->where('user_id', $user->id)->whereNull('deleted_at')->get(['memory_id', 'body', 'created_at']),
            ],
            'notes' => [
                'photos' => 'Photo content is end-to-end encrypted. The app downloads and decrypts each photo on your device when you export.',
            ],
        ];
    }

    private function hasRenewingStoreSubscription(Couple $couple): bool
    {
        return CoupleSubscription::where('couple_id', $couple->id)
            ->live()
            ->where('auto_renew', true)
            ->where('provider', '!=', 'manual')
            ->exists();
    }

    /** Last member leaves: everything goes through the normal trash → purge path. */
    private function dissolve(Couple $couple, User $user): void
    {
        $photos = MemoryPhoto::whereIn('memory_id', Memory::where('couple_id', $couple->id)->select('id'))->whereNull('deleted_at');

        foreach ($photos->pluck('id') as $photoId) {
            PhotoStorageAudit::record($photoId, 'trash', 'succeeded', 'system', 'Account deleted by last couple member.');
        }

        $photos->update(['deleted_at' => now(), 'updated_at' => now()]);
        Memory::where('couple_id', $couple->id)->delete();
        Date::where('couple_id', $couple->id)->delete();
        DB::table('couple_invitations')->where('couple_id', $couple->id)->delete();
    }
}
