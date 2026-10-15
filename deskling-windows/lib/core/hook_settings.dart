import 'dart:convert';

import 'hook_event.dart';

class InvalidSettingsException implements Exception {
  const InvalidSettingsException();

  @override
  String toString() => 'settings.json is not a JSON object with a valid hooks section';
}

/// Adds and removes Deskling's hook entries in a Claude Code settings.json, keeping everything else in order.
class HookSettings {
  static const marker = 'deskling-hook';
  static const timeoutSeconds = 5;

  static Map<String, Object?> entry(String hookCommand, HookKind kind) => {
        'type': 'command',
        'command': hookCommand,
        'args': [kind.wireName],
        'timeout': timeoutSeconds,
      };

  static String install(String? text, String hookCommand) {
    final root = _decode(text);
    final section = _hooksSection(root);
    for (final kind in HookKind.values) {
      final groups = _strip(section[kind.wireName] ?? []);
      groups.add({
        'hooks': [entry(hookCommand, kind)],
      });
      section[kind.wireName] = groups;
    }
    root['hooks'] = section;
    return _encode(root);
  }

  static String uninstall(String text) {
    final root = _decode(text);
    final section = _hooksSection(root);
    for (final event in section.keys.toList()) {
      final remaining = _strip(section[event]!);
      if (remaining.isEmpty) {
        section.remove(event);
      } else {
        section[event] = remaining;
      }
    }
    if (section.isEmpty) {
      root.remove('hooks');
    } else {
      root['hooks'] = section;
    }
    return _encode(root);
  }

  static bool isInstalled(String? text) {
    try {
      final section = _hooksSection(_decode(text));
      return section.values.any((groups) => groups.any((group) => _hooks(group).any(_isOurs)));
    } on InvalidSettingsException {
      return false;
    }
  }

  static String manualSnippet(String hookCommand) => install(null, hookCommand);

  static Map<String, Object?> _decode(String? raw) {
    // Notepad saves UTF-8 with a byte order mark; JSON parsers reject it.
    final text = raw != null && raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    if (text == null || text.trim().isEmpty) return <String, Object?>{};
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const InvalidSettingsException();
    }
    if (root is! Map<String, Object?>) throw const InvalidSettingsException();
    return root;
  }

  static String _encode(Map<String, Object?> root) => '${const JsonEncoder.withIndent('  ').convert(root)}\n';

  static Map<String, List<Map<String, Object?>>> _hooksSection(Map<String, Object?> root) {
    final raw = root['hooks'];
    if (raw == null) return {};
    if (raw is! Map<String, Object?>) throw const InvalidSettingsException();
    final result = <String, List<Map<String, Object?>>>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (value is! List || value.any((group) => group is! Map<String, Object?>)) {
        throw const InvalidSettingsException();
      }
      result[key] = value.cast<Map<String, Object?>>().toList();
    }
    return result;
  }

  static List<Map<String, Object?>> _hooks(Map<String, Object?> group) {
    final hooks = group['hooks'];
    return hooks is List ? hooks.whereType<Map<String, Object?>>().toList() : [];
  }

  static bool _isOurs(Map<String, Object?> hook) {
    final command = hook['command'];
    return command is String && command.contains(marker);
  }

  /// Removes our hook entries, dropping groups that held nothing else.
  static List<Map<String, Object?>> _strip(List<Map<String, Object?>> groups) {
    final result = <Map<String, Object?>>[];
    for (final group in groups) {
      final all = _hooks(group);
      final kept = all.where((hook) => !_isOurs(hook)).toList();
      if (kept.length == all.length) {
        result.add(group);
      } else if (kept.isNotEmpty) {
        result.add({...group, 'hooks': kept});
      }
    }
    return result;
  }
}
