import 'dart:convert';
import 'dart:typed_data';

enum HookKind {
  sessionStart('SessionStart'),
  userPromptSubmit('UserPromptSubmit'),
  preToolUse('PreToolUse'),
  postToolUse('PostToolUse'),
  notification('Notification'),
  stop('Stop'),
  sessionEnd('SessionEnd');

  const HookKind(this.wireName);
  final String wireName;

  static HookKind? fromWire(String name) {
    for (final kind in values) {
      if (kind.wireName == name) return kind;
    }
    return null;
  }
}

/// Extracts the folder name from a Windows or POSIX path. A bare drive such as `C:\` has no name.
String? projectNameOf(String? cwd) {
  if (cwd == null) return null;
  final parts = cwd.split(RegExp(r'[\\/]+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  final last = parts.last;
  if (parts.length == 1 && RegExp(r'^[A-Za-z]:$').hasMatch(last)) return null;
  return last;
}

class HookEvent {
  static const maxMessageLength = 300;
  static const _forwardedKeys = ['hook_event_name', 'session_id', 'cwd', 'message', 'notification_type', 'prompt'];

  const HookEvent({
    required this.kind,
    required this.sessionId,
    this.cwd,
    this.message,
    this.notificationType,
    this.prompt,
    this.token,
  });

  final HookKind kind;
  final String sessionId;
  final String? cwd;
  final String? message;
  final String? notificationType;

  /// What the user asked for, sent with `UserPromptSubmit`.
  final String? prompt;

  /// The app's endpoint token, added by the hook helper.
  final String? token;

  String? get projectName => projectNameOf(cwd);

  /// Claude Code sends this notification about a minute after it finishes. The pet already showed "done".
  bool get isIdlePrompt {
    if (kind != HookKind.notification) return false;
    if (notificationType == 'idle_prompt') return true;
    return message?.toLowerCase().contains('waiting for your input') ?? false;
  }

  /// Only permission and input requests need the user. Other notifications do not.
  bool get requestsAttention {
    if (kind != HookKind.notification) return false;
    switch (notificationType) {
      case 'permission_prompt':
      case 'elicitation_dialog':
        return true;
      case null:
        return !isIdlePrompt;
      default:
        return false;
    }
  }

  static HookEvent? parse(List<int> line) {
    final Object? object;
    try {
      object = jsonDecode(utf8.decode(line));
    } on FormatException {
      return null;
    }
    if (object is! Map<String, dynamic>) return null;
    final map = object;
    String? text(String key) => map[key] is String ? map[key] as String : null;
    final name = text('hook_event_name');
    final kind = name == null ? null : HookKind.fromWire(name);
    final sessionId = text('session_id');
    if (kind == null || sessionId == null || sessionId.isEmpty) return null;
    return HookEvent(
      kind: kind,
      sessionId: sessionId,
      cwd: text('cwd'),
      message: text('message'),
      notificationType: text('notification_type'),
      prompt: text('prompt'),
      token: text('token'),
    );
  }

  /// Reduces a hook payload to the fields the app reads, as one newline-terminated line.
  static Uint8List? compactLine(List<int> input, {String? eventOverride, String? token}) {
    final Object? object;
    try {
      object = jsonDecode(utf8.decode(input, allowMalformed: true));
    } on FormatException {
      return null;
    }
    if (object is! Map<String, dynamic>) return null;
    if (eventOverride != null) object['hook_event_name'] = eventOverride;
    final output = <String, String>{};
    for (final key in _forwardedKeys) {
      final value = object[key];
      if (value is String) output[key] = value;
    }
    for (final key in ['message', 'prompt']) {
      final value = output[key];
      if (value != null && value.runes.length > maxMessageLength) {
        output[key] = String.fromCharCodes(value.runes.take(maxMessageLength));
      }
    }
    if (output['hook_event_name'] == null || output['session_id'] == null) return null;
    if (token != null) output['token'] = token;
    return Uint8List.fromList(utf8.encode('${jsonEncode(output)}\n'));
  }
}

/// Splits a byte stream into newline-terminated lines, dropping blank lines and runaway data.
class EventLineSplitter {
  static const maxPending = 1048576;
  List<int> _pending = [];

  List<List<int>> append(List<int> chunk) {
    _pending = [..._pending, ...chunk];
    final lines = <List<int>>[];
    var index = _pending.indexOf(0x0A);
    while (index >= 0) {
      final line = _pending.sublist(0, index);
      _pending = _pending.sublist(index + 1);
      if (line.isNotEmpty) lines.add(line);
      index = _pending.indexOf(0x0A);
    }
    if (_pending.length > maxPending) _pending = [];
    return lines;
  }

  List<int>? finish() {
    final rest = _pending;
    _pending = [];
    return rest.isEmpty ? null : rest;
  }
}
