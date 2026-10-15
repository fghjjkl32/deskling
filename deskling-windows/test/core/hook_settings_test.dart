import 'dart:convert';

import 'package:deskling/core/hook_event.dart';
import 'package:deskling/core/hook_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const hook = r'C:\Users\Me Too\AppData\Roaming\Deskling\deskling-hook.exe';

Map<String, dynamic> object(String text) => jsonDecode(text) as Map<String, dynamic>;

List<Map<String, dynamic>> entries(Map<String, dynamic> root, String event) {
  final groups = ((root['hooks'] as Map<String, dynamic>?)?[event] as List?) ?? [];
  return [
    for (final group in groups) ...((group as Map<String, dynamic>)['hooks'] as List).cast<Map<String, dynamic>>(),
  ];
}

List<String> commands(Map<String, dynamic> root, String event) =>
    entries(root, event).map((entry) => entry['command'] as String).toList();

void main() {
  test('install into a missing or empty file writes exec-form entries for all seven events', () {
    for (final input in [null, '', '  \n']) {
      final root = object(HookSettings.install(input, hook));
      expect(HookKind.values.length, 7);
      for (final kind in HookKind.values) {
        expect(entries(root, kind.wireName), [
          {
            'type': 'command',
            'command': hook,
            'args': [kind.wireName],
            'timeout': 5,
          },
        ]);
      }
    }
  });

  test('install keeps existing settings, hooks and key order', () {
    const input =
        '{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}],"PostToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"fmt"}]}]},"zeta":1,"alpha":2}';
    final output = HookSettings.install(input, hook);
    final root = object(output);
    expect(root.keys.toList(), ['model', 'hooks', 'zeta', 'alpha']);
    expect(root['model'], 'opus');
    expect(commands(root, 'Stop'), ['say done', hook]);
    expect(commands(root, 'PostToolUse'), ['fmt', hook]);
    expect(((root['hooks'] as Map)['PostToolUse'] as List).first['matcher'], 'Edit');
    expect(output, startsWith('{\n  "model": "opus",\n'));
    expect(output, endsWith('}\n'));
  });

  test('install twice does not duplicate and replaces an old path', () {
    final once = HookSettings.install(null, '/old/deskling-hook');
    final twice = HookSettings.install(once, hook);
    expect(commands(object(twice), 'Stop'), [hook]);
  });

  test('uninstall removes only our entries', () {
    const input = '{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}';
    final root = object(HookSettings.uninstall(HookSettings.install(input, hook)));
    expect(root['model'], 'opus');
    expect(commands(root, 'Stop'), ['say done']);
    expect((root['hooks'] as Map).containsKey('Notification'), false);
  });

  test('uninstall removes an empty hooks section', () {
    final root = object(HookSettings.uninstall(HookSettings.install('{"model":"opus"}', hook)));
    expect(root.containsKey('hooks'), false);
    expect(root['model'], 'opus');
  });

  test('uninstall keeps a user hook sharing our group', () {
    const input =
        '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"},{"type":"command","command":"/x/deskling-hook.exe","args":["Stop"]}]}]}}';
    expect(commands(object(HookSettings.uninstall(input)), 'Stop'), ['say done']);
  });

  test('invalid shapes throw and are not installed', () {
    for (final text in ['{ broken', '[1,2]', '{"hooks":[]}', '{"hooks":{"Stop":"oops"}}', '{"hooks":{"Stop":["oops"]}}']) {
      expect(() => HookSettings.install(text, hook), throwsA(isA<InvalidSettingsException>()), reason: text);
      expect(() => HookSettings.uninstall(text), throwsA(isA<InvalidSettingsException>()), reason: text);
      expect(HookSettings.isInstalled(text), false, reason: text);
    }
  });

  test('isInstalled', () {
    expect(HookSettings.isInstalled(null), false);
    expect(HookSettings.isInstalled('{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}'), false);
    expect(HookSettings.isInstalled(HookSettings.install(null, hook)), true);
  });

  test('the manual snippet is valid JSON with all events', () {
    expect((object(HookSettings.manualSnippet(hook))['hooks'] as Map).length, HookKind.values.length);
  });

  test('a byte order mark from Notepad is accepted and dropped', () {
    const input = '\uFEFF{"model":"opus"}';
    expect(HookSettings.isInstalled(input), false);
    final output = HookSettings.install(input, hook);
    expect(output.startsWith('\uFEFF'), false);
    expect(object(output)['model'], 'opus');
    expect(HookSettings.isInstalled('\uFEFF$output'), true);
  });

  test('a Korean user name in the helper path is kept as is', () {
    const korean = r'C:\Users\홍길동\AppData\Roaming\Deskling\deskling-hook.exe';
    expect(commands(object(HookSettings.install(null, korean)), 'Stop'), [korean]);
  });

  test('non-ASCII text survives a round trip', () {
    const input = '{"statusLine":"작업 중 ✓","hooks":{}}';
    expect(object(HookSettings.uninstall(HookSettings.install(input, hook)))['statusLine'], '작업 중 ✓');
  });
}
