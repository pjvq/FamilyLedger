import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Thrown when a backup file can't be read or decrypted (bad magic, version,
/// wrong passphrase / corrupted data).
class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => 'BackupException: $message';
}

/// Encrypted backup container format + crypto, ported from design §9.2.
///
/// A backup file is:
/// ```
///   magic "FLBK" (4 bytes)
///   formatVersion (1 byte)
///   schemaVersion (uint16, big-endian)   — the Drift schema the payload came from
///   saltLen (1 byte) | salt
///   nonceLen (1 byte) | nonce
///   ciphertext (AES-256-GCM, includes the 16-byte tag appended)
/// ```
/// The key is derived from the user passphrase via **Argon2id**. Payload is the
/// caller's plaintext bytes (e.g. a JSON database snapshot).
///
/// Pure + injectable KDF parameters so it is fully unit-testable; no Drift /
/// platform knowledge.
class BackupCodec {
  BackupCodec({
    this.argonMemory = 19456, // 19 MiB (OWASP Argon2id minimum)
    this.argonIterations = 2,
    this.argonParallelism = 1,
  });

  /// Argon2id memory cost in KiB.
  final int argonMemory;
  final int argonIterations;
  final int argonParallelism;

  static const List<int> _magic = [0x46, 0x4C, 0x42, 0x4B]; // "FLBK"
  static const int formatVersion = 1;
  static const int _keyBytes = 32; // AES-256
  static const int _saltBytes = 16;

  final AesGcm _aes = AesGcm.with256bits();

  /// Encrypt [payload] under [passphrase], tagging the file with [schemaVersion].
  Future<Uint8List> encrypt({
    required Uint8List payload,
    required String passphrase,
    required int schemaVersion,
  }) async {
    if (passphrase.isEmpty) {
      throw BackupException('passphrase must not be empty');
    }
    final salt = _randomBytes(_saltBytes);
    final key = await _deriveKey(passphrase, salt);
    final secretBox = await _aes.encrypt(payload, secretKey: key);

    final nonce = Uint8List.fromList(secretBox.nonce);
    // ciphertext || tag
    final body = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    final out = BytesBuilder();
    out.add(_magic);
    out.addByte(formatVersion);
    out.add(_uint16(schemaVersion));
    out.addByte(salt.length);
    out.add(salt);
    out.addByte(nonce.length);
    out.add(nonce);
    out.add(body);
    return out.toBytes();
  }

  /// Header read from a backup file without decrypting the payload.
  /// Useful to check [schemaVersion] before attempting a restore.
  ({int formatVersion, int schemaVersion}) readHeader(Uint8List file) {
    final r = _Reader(file);
    if (!_listEq(r.take(4), _magic)) {
      throw BackupException('not a FamilyLedger backup (bad magic)');
    }
    final fmt = r.byte();
    if (fmt != formatVersion) {
      throw BackupException('unsupported backup format version $fmt');
    }
    final schema = _readUint16(r.take(2));
    return (formatVersion: fmt, schemaVersion: schema);
  }

  /// Decrypt a backup [file] with [passphrase]. Throws [BackupException] on bad
  /// magic/version or wrong passphrase / tampered data.
  Future<({Uint8List payload, int schemaVersion})> decrypt({
    required Uint8List file,
    required String passphrase,
  }) async {
    final r = _Reader(file);
    if (!_listEq(r.take(4), _magic)) {
      throw BackupException('not a FamilyLedger backup (bad magic)');
    }
    final fmt = r.byte();
    if (fmt != formatVersion) {
      throw BackupException('unsupported backup format version $fmt');
    }
    final schemaVersion = _readUint16(r.take(2));
    final salt = r.lenPrefixed();
    final nonce = r.lenPrefixed();
    final body = r.rest();
    if (body.length < 16) {
      throw BackupException('backup truncated');
    }
    final cipherText = body.sublist(0, body.length - 16);
    final mac = Mac(body.sublist(body.length - 16));

    final key = await _deriveKey(passphrase, salt);
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return (payload: Uint8List.fromList(clear), schemaVersion: schemaVersion);
    } on SecretBoxAuthenticationError {
      throw BackupException('wrong passphrase or corrupted backup');
    }
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) async {
    final kdf = Argon2id(
      memory: argonMemory,
      iterations: argonIterations,
      parallelism: argonParallelism,
      hashLength: _keyBytes,
    );
    return kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int n) {
    final r = SecretKeyData.random(length: n);
    return Uint8List.fromList(r.bytes);
  }

  static Uint8List _uint16(int v) {
    if (v < 0 || v > 0xFFFF) throw BackupException('schemaVersion out of range');
    return Uint8List.fromList([(v >> 8) & 0xFF, v & 0xFF]);
  }

  static int _readUint16(List<int> b) => (b[0] << 8) | b[1];

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Minimal sequential byte reader with bounds checks.
class _Reader {
  _Reader(this._b);
  final Uint8List _b;
  int _i = 0;

  int byte() {
    if (_i >= _b.length) throw BackupException('backup truncated');
    return _b[_i++];
  }

  Uint8List take(int n) {
    if (_i + n > _b.length) throw BackupException('backup truncated');
    final out = _b.sublist(_i, _i + n);
    _i += n;
    return out;
  }

  Uint8List lenPrefixed() => take(byte());

  Uint8List rest() => _b.sublist(_i);
}
