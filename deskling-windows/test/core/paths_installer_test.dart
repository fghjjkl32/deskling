import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:deskling/core/hook_installer.dart';
import 'package:deskling/core/hook_settings.dart';
import 'package:deskling/core/paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

List<int> utf16le(String text, {bool bom = false}) => [
      if (bom) ...[0xFF, 0xFE],
      for (final unit in text.codeUnits) ...[unit & 0xFF, unit >> 8],
    ];

void main() {
  group('paths', () {
    test('support files live under APPDATA', () {
      final paths = AppPaths({'APPDATA': r'C:\Users\Me\AppData\Roaming', 'USERPROFILE': r'C:\Users\Me'}, context: p.windows);
      expect(paths.supportDirectory, r'C:\Users\Me\AppData\Roaming\Deskling');
      expect(paths.skinsDirectory, r'C:\Users\Me\AppData\Roaming\Deskling\skins');
      expect(paths.endpointFile, r'C:\Users\Me\AppData\Roaming\Deskling\endpoint.json');
      expect(paths.installedHook, r'C:\Users\Me\AppData\Roaming\Deskling\deskling-hook.exe');
      expect(paths.instanceLock, r'C:\Users\Me\AppData\Roaming\Deskling\instance.lock');
      expect(paths.claudeSettings, r'C:\Users\Me\.claude\settings.json');
    });

    test('CLAUDE_CONFIG_DIR moves settings.json', () {
      final paths = AppPaths({'USERPROFILE': r'C:\Users\Me', 'CLAUDE_CONFIG_DIR': r'D:\claude'}, context: p.windows);
      expect(paths.claudeSettings, r'D:\claude\settings.json');
      final empty = AppPaths({'USERPROFILE': r'C:\Users\Me', 'CLAUDE_CONFIG_DIR': ''}, context: p.windows);
      expect(empty.claudeSettings, r'C:\Users\Me\.claude\settings.json');
    });

    test('endpoint round trip and rejection', () {
      final token = Endpoint.newToken(Random(1));
      expect(token, hasLength(64));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(token), true);
      final endpoint = Endpoint.decode(Endpoint(port: 51234, token: token).encode())!;
      expect(endpoint.port, 51234);
      expect(endpoint.token, token);
      for (final bad in ['', 'x', '[]', '{"port":0,"token":"a"}', '{"port":70000,"token":"a"}', '{"port":1,"token":""}', '{"port":"1","token":"a"}']) {
        expect(Endpoint.decode(bad), isNull, reason: bad);
      }
      expect(Endpoint.read('/no/such/endpoint.json'), isNull);
    });

    test('WSL distribution list is UTF-16 and skips Docker', () {
      expect(Wsl.parseDistributions(utf16le('Ubuntu\r\ndocker-desktop\r\nDebian\r\n\r\n', bom: true)), ['Ubuntu', 'Debian']);
      expect(Wsl.parseDistributions(utf16le('Ubuntu-22.04\x00\r\n')), ['Ubuntu-22.04']);
      expect(Wsl.parseDistributions([]), isEmpty);
    });

    test('WSL paths', () {
      expect(Wsl.settingsPath('Ubuntu', '/home/me'), r'\\wsl$\Ubuntu\home\me\.claude\settings.json');
      expect(Wsl.settingsPath('Ubuntu', '/root/'), r'\\wsl$\Ubuntu\root\.claude\settings.json');
      expect(Wsl.mountPath(r'C:\Users\Me Too\AppData\Roaming\Deskling\deskling-hook.exe'),
          '/mnt/c/Users/Me Too/AppData/Roaming/Deskling/deskling-hook.exe');
      expect(Wsl.mountPath(r'C:\Users\홍길동\x.exe'), '/mnt/c/Users/홍길동/x.exe');
      expect(Wsl.mountPath('relative\\x.exe'), isNull);
    });
  });

  group('installer', () {
    late Directory root;
    late HookInstaller installer;
    late ConnectionTarget target;

    setUp(() {
      root = Directory.systemTemp.createTempSync('deskling-installer-');
      final bundled = File(p.join(root.path, 'app', 'deskling-hook.exe'))..createSync(recursive: true);
      bundled.writeAsStringSync('new helper');
      installer = HookInstaller(
        supportDirectory: p.join(root.path, 'support'),
        bundledHook: bundled.path,
        retryDelay: Duration.zero,
      );
      target = ConnectionTarget(
        label: 'Windows',
        settingsPath: p.join(root.path, '.claude', 'settings.json'),
        hookCommand: installer.installedHook,
      );
    });
    tearDown(() => root.deleteSync(recursive: true));

    File settings() => File(target.settingsPath);
    File backup() => File(HookInstaller.backupPath(target.settingsPath));

    test('connect creates settings and copies the helper', () async {
      await installer.connect(target);
      expect(installer.isConnected(target), true);
      expect(File(installer.installedHook).readAsStringSync(), 'new helper');
      expect(backup().existsSync(), false);
      expect(Directory(installer.supportDirectory).listSync().map((e) => p.basename(e.path)), ['deskling-hook.exe']);
    });

    test('connect backs up the original once and keeps it', () async {
      settings()
        ..createSync(recursive: true)
        ..writeAsStringSync('{"model":"opus"}');
      await installer.connect(target);
      expect(backup().readAsStringSync(), '{"model":"opus"}');
      await installer.connect(target);
      expect(backup().readAsStringSync(), '{"model":"opus"}');
      expect(jsonDecode(settings().readAsStringSync())['model'], 'opus');
    });

    test('connect leaves an invalid file untouched', () async {
      settings()
        ..createSync(recursive: true)
        ..writeAsStringSync('{ broken');
      await expectLater(installer.connect(target), throwsA(isA<InvalidSettingsException>()));
      expect(settings().readAsStringSync(), '{ broken');
      expect(backup().existsSync(), false);
      expect(File(installer.installedHook).existsSync(), false);
    });

    test('disconnect removes our hooks and keeps other settings', () async {
      settings()
        ..createSync(recursive: true)
        ..writeAsStringSync('{"model":"opus"}');
      await installer.connect(target);
      installer.disconnect(target);
      expect(installer.isConnected(target), false);
      expect(jsonDecode(settings().readAsStringSync()), {'model': 'opus'});
    });

    test('disconnect without a file or without our hooks changes nothing', () {
      installer.disconnect(target);
      expect(settings().existsSync(), false);
      settings()
        ..createSync(recursive: true)
        ..writeAsStringSync('{"model":"opus"}   ');
      installer.disconnect(target);
      expect(settings().readAsStringSync(), '{"model":"opus"}   ');
    });

    test('disconnect of an invalid file throws and leaves it untouched', () {
      settings()
        ..createSync(recursive: true)
        ..writeAsStringSync('{ broken');
      expect(() => installer.disconnect(target), throwsA(isA<InvalidSettingsException>()));
      expect(settings().readAsStringSync(), '{ broken');
    });

    test('an unreadable settings.json is never overwritten', () async {
      final utf16 = [0xFF, 0xFE, for (final unit in '{"model":"opus"}'.codeUnits) ...[unit & 0xFF, unit >> 8]];
      settings()
        ..createSync(recursive: true)
        ..writeAsBytesSync(utf16);
      expect(() => installer.isConnected(target), returnsNormally);
      expect(installer.isConnected(target), false);
      await expectLater(installer.connect(target), throwsA(isA<InvalidSettingsException>()));
      expect(() => installer.disconnect(target), throwsA(isA<InvalidSettingsException>()));
      expect(settings().readAsBytesSync(), utf16);
      expect(backup().existsSync(), false);
    });

    test('copyHelper replaces an older copy and leaves no temporary files', () async {
      File(installer.installedHook)
        ..createSync(recursive: true)
        ..writeAsStringSync('old helper');
      await installer.copyHelper();
      expect(File(installer.installedHook).readAsStringSync(), 'new helper');
      expect(Directory(installer.supportDirectory).listSync(), hasLength(1));
    });

    test('copyHelper failure keeps the previous helper', () async {
      File(installer.installedHook)
        ..createSync(recursive: true)
        ..writeAsStringSync('old helper');
      final broken = HookInstaller(
        supportDirectory: installer.supportDirectory,
        bundledHook: p.join(root.path, 'missing.exe'),
        retryDelay: Duration.zero,
      );
      await expectLater(broken.copyHelper(), throwsA(isA<FileSystemException>()));
      expect(File(installer.installedHook).readAsStringSync(), 'old helper');
      expect(Directory(installer.supportDirectory).listSync(), hasLength(1));
    });

    test('connect writes through a symlink, even a dangling relative one', () async {
      if (Platform.isWindows) return; // Creating links needs developer mode on Windows.
      final real = p.join(root.path, 'dotfiles', 'claude.json');
      Directory(p.dirname(real)).createSync(recursive: true);
      Directory(p.dirname(target.settingsPath)).createSync(recursive: true);
      Link(target.settingsPath).createSync(p.join('..', 'dotfiles', 'claude.json'));
      await installer.connect(target);
      expect(FileSystemEntity.isLinkSync(target.settingsPath), true);
      expect(HookSettings.isInstalled(File(real).readAsStringSync()), true);
    });
  });
}
