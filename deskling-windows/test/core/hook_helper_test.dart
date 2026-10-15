import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deskling/core/hook_event.dart';
import 'package:deskling/core/paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Runs bin/deskling_hook.dart as Claude Code would, with APPDATA pointing at a temporary folder.
Future<ProcessResult> runHook(String appData, String input, List<String> arguments) async {
  final process = await Process.start(
    'dart',
    ['run', 'bin/deskling_hook.dart', ...arguments],
    environment: {'APPDATA': appData},
  );
  process.stdin.write(input);
  await process.stdin.close();
  final stdout = await process.stdout.transform(utf8.decoder).join();
  final stderr = await process.stderr.transform(utf8.decoder).join();
  return ProcessResult(process.pid, await process.exitCode, stdout, stderr);
}

void main() {
  late Directory appData;

  setUp(() => appData = Directory.systemTemp.createTempSync('deskling-hook-'));
  tearDown(() => appData.deleteSync(recursive: true));

  test('sends one compact line with the token and exits 0 silently', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<List<int>>();
    server.listen((socket) async {
      final bytes = await socket.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
      if (!received.isCompleted) received.complete(bytes);
    });
    final paths = AppPaths({'APPDATA': appData.path});
    Directory(paths.supportDirectory).createSync(recursive: true);
    File(paths.endpointFile).writeAsStringSync(Endpoint(port: server.port, token: 'secret').encode());

    final result = await runHook(appData.path, '{"session_id":"s1","cwd":"/w/app","tool_input":{"x":1}}', ['Stop']);
    final line = await received.future.timeout(const Duration(seconds: 10));
    await server.close();

    expect(result.exitCode, 0);
    expect(result.stdout, isEmpty);
    expect(line.last, 0x0A);
    final event = HookEvent.parse(line.sublist(0, line.length - 1))!;
    expect(event.kind, HookKind.stop);
    expect(event.token, 'secret');
    expect(event.projectName, 'app');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('exits 0 silently when the app is not running', () async {
    final result = await runHook(appData.path, '{"session_id":"s1"}', ['Stop']);
    expect(result.exitCode, 0);
    expect(result.stdout, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('exits 0 silently when the endpoint is stale or the input is garbage', () async {
    final paths = AppPaths({'APPDATA': appData.path});
    Directory(paths.supportDirectory).createSync(recursive: true);
    final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = unused.port;
    await unused.close();
    File(paths.endpointFile).writeAsStringSync(Endpoint(port: port, token: 't').encode());
    for (final input in ['{"session_id":"s1"}', 'garbage', '']) {
      final result = await runHook(appData.path, input, ['Stop']);
      expect(result.exitCode, 0, reason: input);
      expect(result.stdout, isEmpty, reason: input);
    }
    expect(p.isAbsolute(paths.endpointFile), true);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
