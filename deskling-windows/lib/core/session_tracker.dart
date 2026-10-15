import 'hook_event.dart';

/// Ordered by priority: a higher index wins when several sessions are tracked.
enum PetState { idle, done, working, waiting }

class PetDisplay {
  const PetDisplay({required this.state, this.projectName, this.message, this.title});

  static const idle = PetDisplay(state: PetState.idle);

  final PetState state;
  final String? projectName;
  final String? message;

  /// The session's latest prompt, which tells sessions in the same folder apart.
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is PetDisplay &&
      other.state == state &&
      other.projectName == projectName &&
      other.message == message &&
      other.title == title;

  @override
  int get hashCode => Object.hash(state, projectName, message, title);

  @override
  String toString() => 'PetDisplay($state, $projectName, $message, $title)';
}

class SessionSummary {
  const SessionSummary({required this.projectName, required this.state, this.title});

  final String? projectName;
  final PetState state;
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is SessionSummary && other.projectName == projectName && other.state == state && other.title == title;

  @override
  int get hashCode => Object.hash(projectName, state, title);

  @override
  String toString() => 'SessionSummary($projectName, $state, $title)';
}

class _Session {
  _Session(this.lastEvent);

  PetState state = PetState.idle;
  DateTime lastEvent;
  String? projectName;
  String? message;
  String? title;
}

class SessionTracker {
  static const doneDuration = Duration(seconds: 5);
  static const workingTimeout = Duration(seconds: 600);
  static const sessionTimeout = Duration(seconds: 1800);

  final _sessions = <String, _Session>{};

  int get sessionCount => _sessions.length;

  void apply(HookEvent event, DateTime now) {
    if (event.kind == HookKind.sessionEnd) {
      _sessions.remove(event.sessionId);
      return;
    }
    final session = _sessions.putIfAbsent(event.sessionId, () => _Session(now));
    session.lastEvent = now;
    final name = event.projectName;
    if (name != null) session.projectName = name;
    final prompt = event.prompt;
    if (event.kind == HookKind.userPromptSubmit && prompt != null && prompt.trim().isNotEmpty) {
      session.title = prompt;
    }
    switch (event.kind) {
      case HookKind.sessionStart:
        session.state = PetState.idle;
        session.message = null;
      case HookKind.userPromptSubmit:
      case HookKind.preToolUse:
      case HookKind.postToolUse:
        session.state = PetState.working;
        session.message = null;
      case HookKind.notification:
        if (event.requestsAttention) {
          session.state = PetState.waiting;
          session.message = event.message;
        }
      case HookKind.stop:
        session.state = PetState.done;
        session.message = null;
      case HookKind.sessionEnd:
        break;
    }
  }

  void tick(DateTime now) {
    _sessions.removeWhere((_, session) => now.difference(session.lastEvent) >= sessionTimeout);
    for (final session in _sessions.values) {
      final elapsed = now.difference(session.lastEvent);
      if (session.state == PetState.done && elapsed >= doneDuration) {
        session.state = PetState.idle;
      } else if (session.state == PetState.working && elapsed >= workingTimeout) {
        session.state = PetState.idle;
      }
    }
  }

  /// Higher state first, then the most recent event.
  static int _byUrgency(_Session a, _Session b) {
    final byState = b.state.index.compareTo(a.state.index);
    return byState != 0 ? byState : b.lastEvent.compareTo(a.lastEvent);
  }

  PetDisplay get display {
    if (_sessions.isEmpty) return PetDisplay.idle;
    final top = (_sessions.values.toList()..sort(_byUrgency)).first;
    return PetDisplay(state: top.state, projectName: top.projectName, message: top.message, title: top.title);
  }

  /// The session that finished most recently and is still "done", whatever the other sessions are doing.
  PetDisplay? get justFinished {
    final finished = _sessions.values.where((session) => session.state == PetState.done).toList()
      ..sort((a, b) => b.lastEvent.compareTo(a.lastEvent));
    if (finished.isEmpty) return null;
    final latest = finished.first;
    return PetDisplay(state: PetState.done, projectName: latest.projectName, title: latest.title);
  }

  /// Every tracked session, most urgent state first and most recent first within a state.
  List<SessionSummary> get summaries => (_sessions.values.toList()..sort(_byUrgency))
      .map((session) => SessionSummary(projectName: session.projectName, state: session.state, title: session.title))
      .toList();
}
