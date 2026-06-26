import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/services/backup/backup_codec.dart';
import 'package:familyledger/domain/services/backup/database_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Fast Argon2id params keep the crypto tests quick (real defaults are heavier).
BackupCodec _fastCodec() =>
    BackupCodec(argonMemory: 256, argonIterations: 1, argonParallelism: 1);

void main() {
  group('BackupCodec', () {
    final codec = _fastCodec();

    test('round-trips payload + schemaVersion with correct passphrase',
        () async {
      final payload = Uint8List.fromList(utf8.encode('hello 账本 🔐'));
      final file =
          await codec.encrypt(payload: payload, passphrase: 'pw', schemaVersion: 24);

      expect(codec.readHeader(file).schemaVersion, 24);
      final out = await codec.decrypt(file: file, passphrase: 'pw');
      expect(out.payload, payload);
      expect(out.schemaVersion, 24);
    });

    test('wrong passphrase fails authentication', () async {
      final file = await codec.encrypt(
        payload: Uint8List.fromList([1, 2, 3]),
        passphrase: 'right',
        schemaVersion: 1,
      );
      expect(
        () => codec.decrypt(file: file, passphrase: 'wrong'),
        throwsA(isA<BackupException>()),
      );
    });

    test('tampered ciphertext fails', () async {
      final file = await codec.encrypt(
        payload: Uint8List.fromList([9, 9, 9, 9]),
        passphrase: 'pw',
        schemaVersion: 1,
      );
      file[file.length - 1] ^= 0xFF; // flip a tag byte
      expect(
        () => codec.decrypt(file: file, passphrase: 'pw'),
        throwsA(isA<BackupException>()),
      );
    });

    test('bad magic is rejected', () async {
      final junk = Uint8List.fromList(List.filled(32, 0));
      expect(() => codec.readHeader(junk), throwsA(isA<BackupException>()));
      expect(
        () => codec.decrypt(file: junk, passphrase: 'pw'),
        throwsA(isA<BackupException>()),
      );
    });

    test('empty passphrase rejected on encrypt', () async {
      expect(
        () => codec.encrypt(
          payload: Uint8List(0),
          passphrase: '',
          schemaVersion: 1,
        ),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('DatabaseBackupService', () {
    late AppDatabase db;
    late DatabaseBackupService svc;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      svc = DatabaseBackupService(db, codec: _fastCodec());
    });
    tearDown(() async => db.close());

    Future<void> seed() async {
      await db.into(db.users).insert(
            UsersCompanion.insert(id: 'u1', email: 'u1@example.com'),
          );
      await db.insertAccount(
        AccountsCompanion.insert(
          id: 'a1',
          userId: 'u1',
          name: '现金',
          balance: const Value(123456),
        ),
      );
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 't1',
              userId: 'u1',
              accountId: 'a1',
              categoryId: 'c1',
              amount: -500,
              amountCny: -500,
              type: 'expense',
              txnDate: DateTime(2026, 6, 1),
              note: const Value('午餐'),
            ),
          );
    }

    test('export → wipe → restore reproduces the data', () async {
      await seed();
      final backup = await svc.exportBackup('secret');

      // Wipe everything.
      await db.customStatement('DELETE FROM users');
      await db.customStatement('DELETE FROM accounts');
      await db.customStatement('DELETE FROM transactions');
      expect(await db.select(db.users).get(), isEmpty);

      await svc.restoreBackup(backup, 'secret');

      final users = await db.select(db.users).get();
      expect(users.map((u) => u.id), ['u1']);
      final accounts = await db.select(db.accounts).get();
      expect(accounts.single.balance, 123456);
      final txns = await db.select(db.transactions).get();
      expect(txns.single.note, '午餐');
      expect(txns.single.txnDate, DateTime(2026, 6, 1));
    });

    test('restore with wrong passphrase throws and leaves data intact',
        () async {
      await seed();
      final backup = await svc.exportBackup('secret');
      expect(
        () => svc.restoreBackup(backup, 'nope'),
        throwsA(isA<BackupException>()),
      );
      // Original data still present (decrypt failed before any DELETE).
      expect(await db.select(db.users).get(), hasLength(1));
    });

    test('refuses a backup from a newer schema', () async {
      await seed();
      // Hand-craft a backup tagged with a far-future schema version.
      final codec = _fastCodec();
      final payload = Uint8List.fromList(
        utf8.encode(jsonEncode({'schemaVersion': 9999, 'tables': {}})),
      );
      final file = await codec.encrypt(
        payload: payload,
        passphrase: 'secret',
        schemaVersion: 9999,
      );
      expect(
        () => svc.restoreBackup(file, 'secret'),
        throwsA(isA<BackupException>()),
      );
    });

    test('blob column values survive the round-trip (base64 path)', () async {
      // SQLite is loosely typed: store raw bytes in a column to exercise the
      // _encodeRow/_decodeRow base64 wrapper (the schema has no blob column yet,
      // so this guards the path defensively).
      final blob = Uint8List.fromList([0, 1, 2, 250, 255, 42]);
      await db.customStatement(
        'INSERT INTO users (id, email) VALUES (?, ?)',
        ['blobuser', blob],
      );

      final backup = await svc.exportBackup('secret');
      await db.customStatement('DELETE FROM users');
      await svc.restoreBackup(backup, 'secret');

      final rows = await db
          .customSelect(
            'SELECT email FROM users WHERE id = ?',
            variables: [Variable<String>('blobuser')],
          )
          .get();
      expect(rows.single.data['email'], blob);
    });
  });
}
