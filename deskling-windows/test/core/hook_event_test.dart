import 'dart:convert';

import 'package:deskling/core/hook_event.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> bytes(String text) => utf8.encode(text);

void main() {
  test('parses a notification', () {
    final event = HookEvent.parse(bytes(
        '{"hook_event_name":"Notification","session_id":"s1","cwd":"C:\\\\Users\\\\me\\\\work\\\\app","message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}'));
    expect(event?.kind, HookKind.notification);
    expect(event?.sessionId, 's1');
    expect(event?.projectName, 'app');
    expect(event?.message, 'Claude needs your permission to use Bash');
    expect(event?.isIdlePrompt, false);
  });

  test('rejects unusable lines', () {
    expect(HookEvent.parse(bytes('not json')), isNull);
    expect(HookEvent.parse(bytes('{"hook_event_name":"Unknown","session_id":"s1"}')), isNull);
    expect(HookEvent.parse(bytes('{"hook_event_name":"Stop"}')), isNull);
    expect(HookEvent.parse(bytes('{"hook_event_name":"Stop","session_id":""}')), isNull);
    expect(HookEvent.parse(bytes('[1,2,3]')), isNull);
    expect(HookEvent.parse([0xff, 0xfe]), isNull);
  });

  test('missing optional fields are null', () {
    final event = HookEvent.parse(bytes('{"hook_event_name":"Stop","session_id":"s1"}'));
    expect(event?.kind, HookKind.stop);
    expect(event?.cwd, isNull);
    expect(event?.projectName, isNull);
    expect(event?.message, isNull);
    expect(event?.token, isNull);
  });

  test('project name comes from Windows and POSIX paths', () {
    expect(projectNameOf(r'C:\Users\me\work\app'), 'app');
    expect(projectNameOf(r'C:\Users\me\work\app\'), 'app');
    expect(projectNameOf('C:/Users/me/work/app'), 'app');
    expect(projectNameOf('/home/me/work/app/'), 'app');
    expect(projectNameOf(r'\\wsl$\Ubuntu\home\me\app'), 'app');
    expect(projectNameOf(r'C:\'), isNull);
    expect(projectNameOf('C:'), isNull);
    expect(projectNameOf('/'), isNull);
    expect(projectNameOf(''), isNull);
    expect(projectNameOf(null), isNull);
  });

  test('idle prompt is detected by type or message', () {
    final byType = HookEvent.parse(bytes('{"hook_event_name":"Notification","session_id":"s1","notification_type":"idle_prompt"}'));
    final byMessage = HookEvent.parse(
        bytes('{"hook_event_name":"Notification","session_id":"s1","message":"Claude is waiting for your input"}'));
    expect(byType?.isIdlePrompt, true);
    expect(byMessage?.isIdlePrompt, true);
  });

  test('compact line drops large fields', () {
    final input = bytes(jsonEncode({
      'hook_event_name': 'PreToolUse',
      'session_id': 's1',
      'cwd': '/a/b',
      'tool_input': {'content': 'x' * 2000000},
    }));
    final line = HookEvent.compactLine(input)!;
    expect(line.length, lessThan(300));
    expect(line.last, 0x0A);
    expect(line.where((byte) => byte == 0x0A).length, 1);
    expect(HookEvent.parse(line.sublist(0, line.length - 1))?.kind, HookKind.preToolUse);
  });

  test('compact line uses the event override and adds the token', () {
    final line = HookEvent.compactLine(bytes('{"session_id":"s1"}'), eventOverride: 'Stop', token: 'abc')!;
    final event = HookEvent.parse(line.sublist(0, line.length - 1));
    expect(event?.kind, HookKind.stop);
    expect(event?.token, 'abc');
  });

  test('compact line forwards and truncates the prompt and message', () {
    for (final key in ['prompt', 'message']) {
      final input = bytes(jsonEncode({'hook_event_name': 'UserPromptSubmit', 'session_id': 's1', key: '가' * 5000}));
      final line = HookEvent.compactLine(input)!;
      final event = HookEvent.parse(line.sublist(0, line.length - 1))!;
      expect((key == 'prompt' ? event.prompt : event.message)!.runes.length, 300, reason: key);
    }
  });

  test('compact line returns null when unusable', () {
    expect(HookEvent.compactLine(bytes('garbage'), eventOverride: 'Stop'), isNull);
    expect(HookEvent.compactLine(bytes('{"hook_event_name":"Stop"}')), isNull);
    expect(HookEvent.compactLine(<int>[], eventOverride: 'Stop'), isNull);
  });

  test('line splitter handles partial and multiple lines', () {
    final splitter = EventLineSplitter();
    expect(splitter.append(bytes('ab')), isEmpty);
    expect(splitter.append(bytes('c\nde\n\nf')), [bytes('abc'), bytes('de')]);
    expect(splitter.finish(), bytes('f'));
    expect(splitter.finish(), isNull);
  });

  test('line splitter drops oversized pending data', () {
    final splitter = EventLineSplitter();
    expect(splitter.append(List.filled(EventLineSplitter.maxPending + 1, 0x41)), isEmpty);
    expect(splitter.finish(), isNull);
  });
}
