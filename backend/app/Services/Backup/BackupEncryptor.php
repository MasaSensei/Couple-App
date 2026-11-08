<?php

namespace App\Services\Backup;

use RuntimeException;

/**
 * Streaming public-key encryption for database dumps, built only from
 * libsodium primitives (no custom cryptography):
 *
 *   "CPDB1" | crypto_box_seal(file_key, recipient_pk) | secretstream header
 *   | repeated [uint32 BE length | secretstream chunk] ... last chunk TAG_FINAL
 *
 * A fresh random file key per backup. Whoever holds only the public key (the
 * app) can write backups but never read them. Chunks are authenticated and
 * ordered, and a missing TAG_FINAL means truncation, so a damaged or
 * shortened backup fails loudly instead of restoring partial data.
 */
class BackupEncryptor
{
    private const MAGIC = 'CPDB1';

    private const CHUNK = 65536;

    /**
     * @param  resource  $in  plaintext
     * @param  resource  $out  ciphertext
     */
    public function encrypt($in, $out, string $publicKeyBase64): void
    {
        $publicKey = base64_decode($publicKeyBase64, true);

        if ($publicKey === false || strlen($publicKey) !== SODIUM_CRYPTO_BOX_PUBLICKEYBYTES) {
            throw new RuntimeException('Invalid backup public key.');
        }

        $fileKey = sodium_crypto_secretstream_xchacha20poly1305_keygen();
        [$state, $header] = sodium_crypto_secretstream_xchacha20poly1305_init_push($fileKey);

        $this->write($out, self::MAGIC.sodium_crypto_box_seal($fileKey, $publicKey).$header);
        sodium_memzero($fileKey);

        // Read one chunk ahead so the last one can carry TAG_FINAL.
        $chunk = $this->readChunk($in);

        while (true) {
            $next = $this->readChunk($in);
            $final = $next === '';
            $cipher = sodium_crypto_secretstream_xchacha20poly1305_push(
                $state,
                $chunk,
                '',
                $final ? SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL : SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_MESSAGE,
            );
            $this->write($out, pack('N', strlen($cipher)).$cipher);

            if ($final) {
                return;
            }

            $chunk = $next;
        }
    }

    /**
     * @param  resource  $in  ciphertext
     * @param  resource  $out  plaintext
     */
    public function decrypt($in, $out, string $secretKeyBase64): void
    {
        $secretKey = base64_decode(trim($secretKeyBase64), true);

        if ($secretKey === false || strlen($secretKey) !== SODIUM_CRYPTO_BOX_SECRETKEYBYTES) {
            throw new RuntimeException('Invalid backup secret key.');
        }

        $keypair = sodium_crypto_box_keypair_from_secretkey_and_publickey(
            $secretKey,
            sodium_crypto_box_publickey_from_secretkey($secretKey),
        );

        if ($this->readExact($in, strlen(self::MAGIC)) !== self::MAGIC) {
            throw new RuntimeException('Not a database backup file.');
        }

        $fileKey = sodium_crypto_box_seal_open($this->readExact($in, 32 + SODIUM_CRYPTO_BOX_SEALBYTES), $keypair);
        sodium_memzero($keypair);

        if ($fileKey === false) {
            throw new RuntimeException('This backup was not encrypted for the given key.');
        }

        $state = sodium_crypto_secretstream_xchacha20poly1305_init_pull(
            $this->readExact($in, SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_HEADERBYTES),
            $fileKey,
        );
        sodium_memzero($fileKey);

        while (true) {
            $length = $this->readExact($in, 4, allowEof: true);

            if ($length === '') {
                throw new RuntimeException('Backup is truncated.');
            }

            $result = sodium_crypto_secretstream_xchacha20poly1305_pull(
                $state,
                $this->readExact($in, unpack('N', $length)[1]),
            );

            if ($result === false) {
                throw new RuntimeException('Backup failed authentication.');
            }

            [$plain, $tag] = $result;
            $this->write($out, $plain);

            if ($tag === SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL) {
                if (! feof($in) && fread($in, 1) !== '') {
                    throw new RuntimeException('Unexpected data after the end of the backup.');
                }

                return;
            }
        }
    }

    private function readChunk($in): string
    {
        $buffer = '';

        while (strlen($buffer) < self::CHUNK && ! feof($in)) {
            $read = fread($in, self::CHUNK - strlen($buffer));

            if ($read === false) {
                throw new RuntimeException('Could not read backup input.');
            }

            if ($read === '') {
                break;
            }

            $buffer .= $read;
        }

        return $buffer;
    }

    private function readExact($in, int $length, bool $allowEof = false): string
    {
        $buffer = '';

        while (strlen($buffer) < $length) {
            $read = fread($in, $length - strlen($buffer));

            if ($read === false || $read === '') {
                if ($allowEof && $buffer === '') {
                    return '';
                }

                throw new RuntimeException('Backup is truncated.');
            }

            $buffer .= $read;
        }

        return $buffer;
    }

    private function write($out, string $data): void
    {
        // Pipes may accept less than the whole buffer per call.
        while ($data !== '') {
            $written = fwrite($out, $data);

            if ($written === false || $written === 0) {
                throw new RuntimeException('Could not write backup output.');
            }

            $data = substr($data, $written);
        }
    }
}
