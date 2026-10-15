import 'dart:io';

import 'package:path/path.dart' as p;

import 'hook_settings.dart';

/// One settings.json to connect: Windows itself, or one WSL distribution.
class ConnectionTarget {
  const ConnectionTarget({required this.label, required this.settingsPath, required this.hookCommand});

  /// `Windows` or the distribution name.
  final String label;
  final String settingsPath;

  /// How that environment starts the helper: a Windows path, or a `/mnt/c/...` path inside WSL.
  final String hookCommand;
}

class HookInstaller {
  HookInstaller({required this.supportDirectory, required this.bundledHook, this.retryDelay = const Duration(milliseconds: 200)});

  static const helperName = 'deskling-hook.exe';
  static const copyAttempts = 5;

  final String supportDirectory;
  final String bundledHook;
  final Duration retryDelay;

  String get installedHook => p.join(supportDirectory, helperName);

  static String backupPath(String settingsPath) => p.join(p.dirname(settingsPath), 'settings.json.deskling-backup');

  bool isConnected(ConnectionTarget target) {
    try {
      return HookSettings.isInstalled(_read(target.settingsPath));
    } on InvalidSettingsException {
      return false;
    }
  }

  /// Copies the helper through a temporary file. A running hook can lock the old copy for a moment, so the
  /// final rename is retried before giving up; a failure keeps the previous helper.
  Future<void> copyHelper() async {
    Directory(supportDirectory).createSync(recursive: true);
    final temporary = p.join(supportDirectory, '.$helperName.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      File(bundledHook).copySync(temporary);
      for (var attempt = 1;; attempt++) {
        try {
          File(temporary).renameSync(installedHook);
          return;
        } on FileSystemException {
          if (attempt >= copyAttempts) rethrow;
          await Future<void>.delayed(retryDelay);
        }
      }
    } finally {
      final leftover = File(temporary);
      if (leftover.existsSync()) leftover.deleteSync();
    }
  }

  /// Throws [InvalidSettingsException] without touching the file when it cannot be merged.
  Future<void> connect(ConnectionTarget target) async {
    final existing = _read(target.settingsPath);
    final merged = HookSettings.install(existing, target.hookCommand);
    await copyHelper();
    if (existing != null && !HookSettings.isInstalled(existing)) {
      File(backupPath(target.settingsPath)).writeAsStringSync(existing);
    }
    _writeAtomically(_writePath(target.settingsPath), merged);
  }

  void disconnect(ConnectionTarget target) {
    final existing = _read(target.settingsPath);
    if (existing == null) return;
    final stripped = HookSettings.uninstall(existing);
    if (!HookSettings.isInstalled(existing)) return;
    _writeAtomically(_writePath(target.settingsPath), stripped);
  }

  /// Null only when the file does not exist. A file that cannot be read or is not UTF-8 (a UTF-16 file from
  /// PowerShell, a locked file) must never be treated as missing, or connecting would replace it.
  static String? _read(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      throw const InvalidSettingsException();
    }
  }

  /// Writing replaces the file, so follow a symlinked settings.json (even a dangling one) to the file it points at.
  static String _writePath(String path) {
    var current = path;
    for (var i = 0; i < 16; i++) {
      final link = Link(current);
      if (FileSystemEntity.typeSync(current, followLinks: false) != FileSystemEntityType.link) break;
      final destination = link.targetSync();
      current = p.isAbsolute(destination) ? destination : p.normalize(p.join(p.dirname(current), destination));
    }
    return current;
  }

  static void _writeAtomically(String path, String text) {
    Directory(p.dirname(path)).createSync(recursive: true);
    final temporary = File('$path.deskling-${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      temporary.writeAsStringSync(text, flush: true);
      temporary.renameSync(path);
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }
}
