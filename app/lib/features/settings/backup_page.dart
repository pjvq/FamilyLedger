import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/providers/backup_provider.dart';
import '../../domain/services/backup/backup_codec.dart';

/// Backup & restore (Android is local-only — this is the only device-migration
/// path; design §9.2 / issue #162).
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(backupStatusProvider).lastBackupAt;
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '本机数据仅保存在本地。导出加密备份文件并妥善保存,是换机或丢失设备后恢复数据的唯一方式。'
                '恢复时需要输入当初设置的备份口令——口令无法找回,请牢记。',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('导出加密备份'),
            subtitle: Text(
              last == null
                  ? '尚未备份过'
                  : '上次备份:${_fmt(last)}',
            ),
            onTap: _busy ? null : _export,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('从备份文件恢复'),
            subtitle: const Text('将用备份内容整体替换当前数据'),
            onTap: _busy ? null : _restore,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final pass = await _askPassphrase(confirm: true);
    if (pass == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(databaseBackupServiceProvider).exportBackup(pass);
      final dir = await getTemporaryDirectory();
      final name = 'familyledger-backup-${_stamp()}.flbk';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await ref.read(backupStatusProvider).markBackedUp(DateTime.now());
      await Share.shareXFiles([XFile(file.path)], subject: name);
      if (mounted) setState(() {}); // refresh "上次备份"
      _toast('备份已生成,请妥善保存文件');
    } catch (e) {
      _toast('备份失败:$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      _toast('无法读取所选文件');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复?'),
        content: const Text('恢复会用备份内容整体替换当前所有数据,且不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final pass = await _askPassphrase(confirm: false);
    if (pass == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(databaseBackupServiceProvider).restoreBackup(bytes, pass);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('恢复完成'),
          content: const Text('数据已恢复,请重启 App 以加载。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } on BackupException catch (e) {
      _toast(_friendly(e));
    } catch (e) {
      _toast('恢复失败:$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(BackupException e) {
    final m = e.message;
    if (m.contains('passphrase') || m.contains('corrupted')) {
      return '口令错误或文件已损坏';
    }
    if (m.contains('magic')) return '不是有效的备份文件';
    if (m.contains('newer')) return '该备份来自更新版本的 App,请先升级';
    return '恢复失败:$m';
  }

  /// Prompts for a passphrase; when [confirm], requires a matching re-entry.
  Future<String?> _askPassphrase({required bool confirm}) {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(confirm ? '设置备份口令' : '输入备份口令'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c1,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '口令'),
                ),
                if (confirm)
                  TextField(
                    controller: c2,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '再次输入'),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (c1.text.isEmpty) {
                    setLocal(() => error = '口令不能为空');
                    return;
                  }
                  if (confirm && c1.text != c2.text) {
                    setLocal(() => error = '两次输入不一致');
                    return;
                  }
                  Navigator.pop(ctx, c1.text);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmt(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  static String _stamp() {
    final d = DateTime.now();
    return '${d.year}${_two(d.month)}${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}';
  }
}
