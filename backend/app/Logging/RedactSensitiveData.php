<?php

namespace App\Logging;

use Illuminate\Log\Logger;
use Monolog\LogRecord;

/**
 * Monolog processor (attached with `tap`) that removes secrets from log
 * records: values under sensitive keys in context/extra, and bearer/API
 * tokens or long key-like strings inside messages.
 *
 * Defence in depth: code should not log these in the first place.
 */
class RedactSensitiveData
{
    public const MASK = '[REDACTED]';

    private const SENSITIVE_KEY = '/pass(word)?|secret|token|authori[sz]ation|cookie|session|api[_-]?key|private[_-]?key|couple[_-]?key|recovery|wrapped|nonce|mac|signature|identity|credential|^key$/i';

    private const MESSAGE_PATTERNS = [
        '/Bearer\s+[A-Za-z0-9._|~+\/=-]+/i' => 'Bearer '.self::MASK,
        '/\b\d+\|[A-Za-z0-9]{40,}\b/' => self::MASK,               // Sanctum plain-text token
        '/\b[A-Z2-7]{4}(?:-[A-Z2-7]{4}){12}\b/' => self::MASK,     // Recovery Key (Base32 groups)
        '/(password|secret|token)=([^&\s]+)/i' => '$1='.self::MASK,
    ];

    public function __invoke(Logger|LogRecord $target): mixed
    {
        // Used as a `tap`: attach to every handler of the channel.
        if ($target instanceof Logger) {
            foreach ($target->getHandlers() as $handler) {
                $handler->pushProcessor($this);
            }

            return null;
        }

        return $target->with(
            message: $this->scrubString($target->message),
            context: $this->scrub($target->context),
            extra: $this->scrub($target->extra),
        );
    }

    private function scrub(array $data, int $depth = 0): array
    {
        foreach ($data as $key => $value) {
            if (is_string($key) && preg_match(self::SENSITIVE_KEY, $key) === 1 && $key !== 'request_id' && ! is_bool($value)) {
                $data[$key] = self::MASK;
            } elseif (is_array($value) && $depth < 6) {
                $data[$key] = $this->scrub($value, $depth + 1);
            } elseif (is_string($value)) {
                $data[$key] = $this->scrubString($value);
            }
        }

        return $data;
    }

    private function scrubString(string $value): string
    {
        return preg_replace(array_keys(self::MESSAGE_PATTERNS), array_values(self::MESSAGE_PATTERNS), $value) ?? $value;
    }
}
