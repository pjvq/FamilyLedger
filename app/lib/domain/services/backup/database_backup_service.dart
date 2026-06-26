import 'dart:convert';
import 'dart:typed_data';

import '../../../data/local/database.dart';
import 'backup_codec.dart';

/// Full-database encrypted backup / restore (design §9.2, issue #161).
///
/// A backup is a JSON snapshot of the domain tables (transient sync / cache
/// tables are excluded), encrypted with [BackupCodec] (AES-256-GCM, key from
/// the user passphrase via Argon2id). Restore is a whole-database replace:
/// every backed-up table is cleared and repopulated inside one transaction.
///
/// Values are snapshotted at the SQLite storage level (`SELECT *`) and
/// re-inserted verbatim, so the round-trip is type-lossless; binary (blob)
/// columns are base64-wrapped for JSON transport.
class DatabaseBackupService {
  DatabaseBackupService(this._db, {BackupCodec? codec})
    : _codec = codec ?? BackupCodec();

  final AppDatabase _db;
  final BackupCodec _codec;

  /// Transient / cache / sync-plumbing tables that must NOT be carried across a
  /// device migration. Everything else in the schema is backed up.
  static const Set<String> _excludedTables = {
    'market_quotes',
    'sync_queue',
    'sync_metadata',
    'sync_dead_letters',
    'category_usage_slots',
    'category_usage_summary',
    'category_merge_log',
    'category_merge_dismissals',
  };

  static const String _b64Key = r'$b64';

  /// Build an encrypted backup of the current database.
  Future<Uint8List> exportBackup(String passphrase) async {
    final snapshot = await _snapshot();
    final payload = Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));
    return _codec.encrypt(
      payload: payload,
      passphrase: passphrase,
      schemaVersion: _db.schemaVersion,
    );
  }

  /// Restore a database from an encrypted backup [file]. Whole-database replace.
  ///
  /// Refuses a backup created by a newer schema than this build (forward-only:
  /// upgrade the app first). Throws [BackupException] on bad file / passphrase.
  Future<void> restoreBackup(Uint8List file, String passphrase) async {
    final result = await _codec.decrypt(file: file, passphrase: passphrase);
    if (result.schemaVersion > _db.schemaVersion) {
      throw BackupException(
        'backup schema v${result.schemaVersion} is newer than this app '
        '(v${_db.schemaVersion}); please update the app first',
      );
    }
    final snapshot = jsonDecode(utf8.decode(result.payload)) as Map;
    final tables = (snapshot['tables'] as Map).cast<String, dynamic>();

    // Table names come from a decrypted (user-supplyable) file — only ever
    // touch real tables of THIS database, never an arbitrary name (the SQLite
    // `"`-quoting wouldn't escape an embedded quote → injection).
    final known = {for (final t in _db.allTables) t.actualTableName};

    await _db.transaction(() async {
      // The app runs with SQLite's default FK enforcement OFF (offline-first
      // sync applies ops out of order), so a whole-DB clear+repopulate needs no
      // parent-before-child ordering and no FK toggling.
      for (final entry in tables.entries) {
        final name = entry.key;
        if (_excludedTables.contains(name) || !known.contains(name)) continue;
        await _db.customStatement('DELETE FROM "$name"');
        for (final raw in (entry.value as List)) {
          final row = _decodeRow((raw as Map).cast<String, dynamic>());
          final cols = row.keys.toList();
          if (cols.isEmpty) continue;
          final colList = cols.map((c) => '"$c"').join(', ');
          final placeholders = List.filled(cols.length, '?').join(', ');
          await _db.customStatement(
            'INSERT INTO "$name" ($colList) VALUES ($placeholders)',
            cols.map((c) => row[c]).toList(),
          );
        }
      }
    });
  }

  Future<Map<String, dynamic>> _snapshot() async {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final table in _db.allTables) {
      final name = table.actualTableName;
      if (_excludedTables.contains(name)) continue;
      final rows = await _db.customSelect('SELECT * FROM "$name"').get();
      out[name] = rows.map((r) => _encodeRow(r.data)).toList();
    }
    return {'schemaVersion': _db.schemaVersion, 'tables': out};
  }

  /// JSON-encode a raw SQLite row: blobs → base64 wrapper, others as-is.
  Map<String, dynamic> _encodeRow(Map<String, Object?> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      out[k] = v is Uint8List ? {_b64Key: base64Encode(v)} : v;
    });
    return out;
  }

  /// Reverse of [_encodeRow]: a single-key `{$b64: ...}` wrapper → Uint8List.
  /// The single-key check avoids misreading a genuine JSON map column (e.g.
  /// `data_json`) that merely happens to contain a `$b64` key.
  Map<String, Object?> _decodeRow(Map<String, dynamic> row) {
    final out = <String, Object?>{};
    row.forEach((k, v) {
      if (v is Map && v.length == 1 && v.containsKey(_b64Key)) {
        out[k] = base64Decode(v[_b64Key] as String);
      } else {
        out[k] = v;
      }
    });
    return out;
  }
}
