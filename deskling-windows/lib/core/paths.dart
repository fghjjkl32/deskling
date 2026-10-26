import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Windows locations, computed from the environment so tests can pass their own.
class AppPaths {
  AppPaths(this.environment, {p.Context? context}) : _windows = context ?? p.context;

  factory AppPaths.current() => AppPaths(Platform.environment);

  final Map<String, String> environment;
  final p.Context _windows;

  String get _appData => environment['APPDATA'] ?? _windows.join(_home, 'AppData', 'Roaming');
  String get _home => environment['USERPROFILE'] ?? environment['HOME'] ?? '';

  String get supportDirectory => _windows.join(_appData, 'Deskling');
  String get skinsDirectory => _windows.join(supportDirectory, 'skins');
  String get endpointFile => _windows.join(supportDirectory, 'endpoint.json');
  String get installedHook => _windows.join(supportDirectory, 'deskling-hook.exe');

  String get claudeSettings {
    final custom = environment['CLAUDE_CONFIG_DIR'];
    if (custom != null && custom.isNotEmpty) return _windows.join(custom, 'settings.json');
    return _windows.join(_home, '.claude', 'settings.json');
  }
}

/// Where the app listens, shared with the hook helper through endpoint.json.
class Endpoint {
  const Endpoint({required this.port, required this.token});

  final int port;
  final String token;

  static String newToken([Random? random]) {
    final source = random ?? Random.secure();
    return List.generate(32, (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  String encode() => jsonEncode({'port': port, 'token': token});

  static Endpoint? decode(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;
      final port = json['port'];
      final token = json['token'];
      if (port is! int || port <= 0 || port > 65535 || token is! String || token.isEmpty) return null;
      return Endpoint(port: port, token: token);
    } on FormatException {
      return null;
    }
  }

  static Endpoint? read(String file) {
    try {
      return decode(File(file).readAsStringSync());
    } on FileSystemException {
      return null;
    }
  }
}

class Wsl {
  /// `wsl.exe -l -q` prints UTF-16LE. Docker Desktop's own distributions are not places users run Claude Code.
  static List<String> parseDistributions(List<int> bytes) {
    final units = <int>[for (var i = 0; i + 1 < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8)];
    final text = String.fromCharCodes(units).replaceAll('\uFEFF', '').replaceAll('\u0000', '');
    return const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .where((name) => name.isNotEmpty && !name.toLowerCase().startsWith('docker-desktop'))
        .toList();
  }

  /// The Windows path of a file in a distribution, such as `\\wsl$\Ubuntu\home\me\.claude\settings.json`.
  static String uncPath(String distro, String linuxPath) =>
      '\\\\wsl\$\\$distro${linuxPath.replaceAll('/', '\\')}';

  /// The settings.json of a distribution whose home is `home`.
  static String settingsPath(String distro, String home) {
    final trimmed = home.endsWith('/') ? home.substring(0, home.length - 1) : home;
    return uncPath(distro, '$trimmed/.claude/settings.json');
  }

  /// `C:\Users\Me\x.exe` → `/mnt/c/Users/Me/x.exe`, the default automount layout. Used when `wslpath` fails.
  static String? mountPath(String windowsPath) {
    final match = RegExp(r'^([A-Za-z]):[\\/](.*)$').firstMatch(windowsPath);
    if (match == null) return null;
    final rest = match.group(2)!.replaceAll('\\', '/');
    return '/mnt/${match.group(1)!.toLowerCase()}/$rest';
  }
}
