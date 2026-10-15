import 'package:deskling/core/hook_event.dart';
import 'package:deskling/core/session_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

final start = DateTime.fromMillisecondsSinceEpoch(1000000000);
DateTime at(double seconds) => start.add(Duration(milliseconds: (seconds * 1000).round()));

HookEvent event(HookKind kind, {String session = 's1', String? cwd = '/work/app', String? message, String? type, String? prompt}) =>
    HookEvent(kind: kind, sessionId: session, cwd: cwd, message: message, notificationType: type, prompt: prompt);

void main() {
  test('latest prompt becomes the session title', () {
    final tracker = SessionTracker();
    tracker.apply(event(HookKind.userPromptSubmit, prompt: 'first'), start);
    tracker.apply(event(HookKind.userPromptSubmit, prompt: 'second'), start);
    tracker.apply(event(HookKind.userPromptSubmit, prompt: '  '), start);
    expect(tracker.display.title, 'second');
    expect(tracker.summaries, [const SessionSummary(projectName: 'app', state: PetState.working, title: 'second')]);
    tracker.apply(event(HookKind.notification, message: 'Need permission'), start);
    expect(tracker.display,
        const PetDisplay(state: PetState.waiting, projectName: 'app', message: 'Need permission', title: 'second'));
    tracker.apply(event(HookKind.stop), start);
    expect(tracker.justFinished, const PetDisplay(state: PetState.done, projectName: 'app', title: 'second'));
  });

  test('empty tracker is idle', () {
    expect(SessionTracker().display, PetDisplay.idle);
  });

  test('event sequence drives state', () {
    final tracker = SessionTracker();
    tracker.apply(event(HookKind.sessionStart), start);
    expect(tracker.display.state, PetState.idle);
    tracker.apply(event(HookKind.userPromptSubmit), start);
    expect(tracker.display.state, PetState.working);
    tracker.apply(event(HookKind.notification, message: 'Need permission'), start);
    expect(tracker.display, const PetDisplay(state: PetState.waiting, projectName: 'app', message: 'Need permission'));
    tracker.apply(event(HookKind.preToolUse), start);
    expect(tracker.display, const PetDisplay(state: PetState.working, projectName: 'app'));
    tracker.apply(event(HookKind.stop), start);
    expect(tracker.display.state, PetState.done);
  });

  test('done becomes idle after five seconds', () {
    final tracker = SessionTracker()..apply(event(HookKind.stop), start);
    tracker.tick(at(4.9));
    expect(tracker.display.state, PetState.done);
    tracker.tick(at(5));
    expect(tracker.display.state, PetState.idle);
  });

  test('working times out after ten minutes', () {
    final tracker = SessionTracker()..apply(event(HookKind.preToolUse), start);
    tracker.tick(at(599));
    expect(tracker.display.state, PetState.working);
    tracker.tick(at(600));
    expect(tracker.display.state, PetState.idle);
  });

  test('stale session is removed after thirty minutes', () {
    final tracker = SessionTracker()..apply(event(HookKind.notification, message: 'm'), start);
    tracker.tick(at(1799));
    expect(tracker.display.state, PetState.waiting);
    tracker.tick(at(1800));
    expect(tracker.sessionCount, 0);
    expect(tracker.display.state, PetState.idle);
  });

  test('session end removes the session', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.preToolUse), start)
      ..apply(event(HookKind.sessionEnd), start);
    expect(tracker.sessionCount, 0);
  });

  test('highest priority state wins', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.stop, session: 'a', cwd: '/w/a'), start)
      ..apply(event(HookKind.preToolUse, session: 'b', cwd: '/w/b'), start);
    expect(tracker.display.projectName, 'b');
    tracker.apply(event(HookKind.notification, session: 'c', cwd: '/w/c', message: 'm'), start);
    expect(tracker.display, const PetDisplay(state: PetState.waiting, projectName: 'c', message: 'm'));
  });

  test('most recent session wins within the same state', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.preToolUse, session: 'a', cwd: '/w/a'), start)
      ..apply(event(HookKind.preToolUse, session: 'b', cwd: '/w/b'), at(1));
    expect(tracker.display.projectName, 'b');
  });

  test('idle prompt does not change state', () {
    final tracker = SessionTracker()..apply(event(HookKind.stop), start);
    tracker.tick(at(10));
    tracker.apply(event(HookKind.notification, message: 'Claude is waiting for your input', type: 'idle_prompt'), at(60));
    expect(tracker.display.state, PetState.idle);
  });

  test('project name is kept when a later event has no cwd', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.userPromptSubmit), start)
      ..apply(event(HookKind.stop, cwd: null), start);
    expect(tracker.display.projectName, 'app');
  });

  test('PostToolUse returns a waiting session to working', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.notification, message: 'Need permission', type: 'permission_prompt'), start);
    expect(tracker.display.state, PetState.waiting);
    tracker.apply(event(HookKind.postToolUse), start);
    expect(tracker.display, const PetDisplay(state: PetState.working, projectName: 'app'));
  });

  test('other notification types leave state unchanged', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.userPromptSubmit), start)
      ..apply(event(HookKind.notification, message: 'signed in', type: 'auth_success'), start);
    expect(tracker.display.state, PetState.working);
    tracker.apply(event(HookKind.notification, message: '?', type: 'something_new'), start);
    expect(tracker.display.state, PetState.working);
  });

  test('attention notification types set waiting', () {
    for (final type in ['permission_prompt', 'elicitation_dialog', null]) {
      final tracker = SessionTracker()
        ..apply(event(HookKind.userPromptSubmit), start)
        ..apply(event(HookKind.notification, message: 'Question', type: type), start);
      expect(tracker.display, const PetDisplay(state: PetState.waiting, projectName: 'app', message: 'Question'),
          reason: '$type');
    }
  });

  test('idle prompt keeps the waiting state', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.notification, message: 'Need permission', type: 'permission_prompt'), start)
      ..apply(event(HookKind.notification, message: 'Claude is waiting for your input', type: 'idle_prompt'), at(60));
    expect(tracker.display, const PetDisplay(state: PetState.waiting, projectName: 'app', message: 'Need permission'));
  });

  test('idle text without a type does not request attention', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.userPromptSubmit), start)
      ..apply(event(HookKind.notification, message: 'Claude is waiting for your input'), start);
    expect(tracker.display.state, PetState.working);
  });

  test('just finished is reported while another session works', () {
    final tracker = SessionTracker()..apply(event(HookKind.preToolUse, session: 'a', cwd: '/w/a'), start);
    expect(tracker.justFinished, isNull);
    tracker.apply(event(HookKind.stop, session: 'b', cwd: '/w/b'), start);
    expect(tracker.display.state, PetState.working);
    expect(tracker.justFinished, const PetDisplay(state: PetState.done, projectName: 'b'));
    tracker.tick(start.add(SessionTracker.doneDuration));
    expect(tracker.justFinished, isNull);
  });

  test('just finished prefers the latest session', () {
    final tracker = SessionTracker()
      ..apply(event(HookKind.stop, session: 'a', cwd: '/w/a'), start)
      ..apply(event(HookKind.stop, session: 'b', cwd: '/w/b'), at(1));
    expect(tracker.justFinished?.projectName, 'b');
  });

  test('summaries list the most urgent and recent first', () {
    final tracker = SessionTracker();
    expect(tracker.summaries, isEmpty);
    tracker
      ..apply(event(HookKind.sessionStart, session: 'a', cwd: '/w/a'), start)
      ..apply(event(HookKind.preToolUse, session: 'b', cwd: '/w/b'), start)
      ..apply(event(HookKind.preToolUse, session: 'c', cwd: '/w/c'), at(1))
      ..apply(event(HookKind.notification, session: 'd', cwd: '/w/d', message: 'm'), start);
    expect(tracker.summaries, const [
      SessionSummary(projectName: 'd', state: PetState.waiting),
      SessionSummary(projectName: 'c', state: PetState.working),
      SessionSummary(projectName: 'b', state: PetState.working),
      SessionSummary(projectName: 'a', state: PetState.idle),
    ]);
  });
}
