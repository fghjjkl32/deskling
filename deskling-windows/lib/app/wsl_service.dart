import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../core/hook_installer.dart';
import '../core/paths.dart';

/// A WSL distribution and, when it answered, the target to connect.
class WslDistro {
  const WslDistro(this.name, this.target, {this.connected = false});

  final String name;

  /// Null when the distribution did not answer in time.
  final ConnectionTarget? target;

  /// Read during the background scan: touching \\wsl\$ can start a stopped distribution and take seconds.
  final bool connected;
}

/// Reads the installed distributions in the background so the tray menu never waits on wsl.exe.
class WslService {
  WslService({required this.installedHook, required this.isConnected});

  static const commandTimeout = Duration(seconds: 3);

  final String installedHook;
  final bool Function(ConnectionTarget target) isConnected;

  /// Null until the first scan finishes; empty when WSL is missing.
  List<WslDistro>? latest;
  Future<void>? _scan;

  Future<void> refresh() => _scan ??= _doScan().whenComplete(() => _scan = null);

  Future<void> _doScan() async {
    final list = await _run(['-l', '-q'], decode: false);
    if (list == null) {
      latest = const [];
      return;
    }
    final names = Wsl.parseDistributions(list as List<int>);
    final hookCommand = await _hookCommand(names);
    final distros = <WslDistro>[];
    // A local copy keeps `this` (and its pending Future) out of the closure sent to the isolate.
    final check = isConnected;
    for (final name in names) {
      final target = await _target(name, hookCommand);
      final connected = target != null && await Isolate.run(() => check(target));
      distros.add(WslDistro(name, target, connected: connected));
    }
    latest = distros;
  }

  /// `wslpath` knows custom automount roots; the default layout is the fallback.
  Future<String?> _hookCommand(List<String> names) async {
    if (names.isEmpty) return null;
    final converted = await _run(['-d', names.first, '-e', 'wslpath', '-u', installedHook]);
    final text = (converted as String?)?.trim();
    return text != null && text.startsWith('/') ? text : Wsl.mountPath(installedHook);
  }

  Future<ConnectionTarget?> _target(String name, String? hookCommand) async {
    final home = ((await _run(['-d', name, '-e', 'sh', '-c', r'printf %s "$HOME"'])) as String?)?.trim();
    if (home == null || !home.startsWith('/') || hookCommand == null) return null;
    return ConnectionTarget(label: name, settingsPath: Wsl.settingsPath(name, home), hookCommand: hookCommand);
  }

  /// Runs wsl.exe with a time limit. Returns null on failure, a timeout, or a non-zero exit.
  static Future<Object?> _run(List<String> arguments, {bool decode = true}) async {
    final Process process;
    try {
      process = await Process.start('wsl.exe', arguments);
    } on ProcessException {
      return null;
    }
    final stdout = process.stdout.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    unawaited(process.stderr.drain<void>());
    final exitCode = await process.exitCode.timeout(commandTimeout, onTimeout: () {
      process.kill();
      return -1;
    });
    if (exitCode != 0) return null;
    final bytes = await stdout;
    return decode ? utf8.decode(bytes, allowMalformed: true) : bytes;
  }
}
