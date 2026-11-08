<?php

namespace Tests\Unit\Services;

use App\Services\Backup\BackupEncryptor;
use PHPUnit\Framework\TestCase;
use RuntimeException;

class BackupEncryptorTest extends TestCase
{
    private function keys(): array
    {
        $keypair = sodium_crypto_box_keypair();

        return [base64_encode(sodium_crypto_box_publickey($keypair)), base64_encode(sodium_crypto_box_secretkey($keypair))];
    }

    private function stream(string $data)
    {
        $stream = fopen('php://memory', 'w+b');
        fwrite($stream, $data);
        rewind($stream);

        return $stream;
    }

    private function encrypt(string $plain, string $publicKey): string
    {
        $out = fopen('php://memory', 'w+b');
        (new BackupEncryptor)->encrypt($this->stream($plain), $out, $publicKey);
        rewind($out);

        return stream_get_contents($out);
    }

    private function decrypt(string $cipher, string $secretKey): string
    {
        $out = fopen('php://memory', 'w+b');
        (new BackupEncryptor)->decrypt($this->stream($cipher), $out, $secretKey);
        rewind($out);

        return stream_get_contents($out);
    }

    public function test_round_trip_across_many_chunks_and_empty_input(): void
    {
        [$public, $secret] = $this->keys();

        foreach (['', 'x', random_bytes(65536), random_bytes(200_000)] as $plain) {
            $this->assertSame($plain, $this->decrypt($this->encrypt($plain, $public), $secret));
        }
    }

    public function test_ciphertext_does_not_contain_plaintext(): void
    {
        [$public] = $this->keys();
        $plain = str_repeat('PGDMP couples PLAINTEXT-MARKER ', 1000);

        $cipher = $this->encrypt($plain, $public);

        $this->assertStringNotContainsString('PLAINTEXT-MARKER', $cipher);
        $this->assertStringNotContainsString('PGDMP', $cipher);
    }

    public function test_wrong_key_is_rejected(): void
    {
        [$public] = $this->keys();
        [, $otherSecret] = $this->keys();

        $this->expectException(RuntimeException::class);
        $this->decrypt($this->encrypt('data', $public), $otherSecret);
    }

    public function test_tampered_byte_is_rejected(): void
    {
        [$public, $secret] = $this->keys();
        $cipher = $this->encrypt(random_bytes(100_000), $public);
        $cipher[intdiv(strlen($cipher), 2)] = chr(ord($cipher[intdiv(strlen($cipher), 2)]) ^ 1);

        $this->expectException(RuntimeException::class);
        $this->decrypt($cipher, $secret);
    }

    public function test_truncated_backup_is_rejected_even_at_a_chunk_boundary(): void
    {
        [$public, $secret] = $this->keys();
        $cipher = $this->encrypt(random_bytes(150_000), $public);

        // Drop the final chunk entirely: every remaining chunk still authenticates.
        // 150 000 bytes = two full 64 KiB chunks + a final 18 928-byte chunk.
        $finalRecord = 4 + (150_000 - 2 * 65536) + SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_ABYTES;
        $truncated = substr($cipher, 0, -$finalRecord);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('truncated');
        $this->decrypt($truncated, $secret);
    }
}
