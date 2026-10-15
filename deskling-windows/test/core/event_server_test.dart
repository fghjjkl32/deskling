import 'dart:convert';
import 'dart:io';

import 'package:deskling/core/event_server.dart';
import 'package:deskling/core/hook_event.dart';
import 'package:deskling/core/paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('deskling-server-'));
  tearDown(() => root.deleteSync(recursive: true));

  Future<void> send(int port, String text) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    socket.add(utf8.encode(text));
    await socket.flush();
    await socket.close();
  }

  test('accepts lines with the token and drops the rest', () async {
    final received = <HookEvent>[];
    final server = EventServer(received.add);
    final file = p.join(root.path, 'Deskling', 'endpoint.json');
    expect(await server.start(file), true);
    final endpoint = Endpoint.read(file)!;
    expect(File('$file.tmp').existsSync(), false);

    await send(endpoint.port,
        '{"hook_event_name":"Stop","session_id":"a","token":"${endpoint.token}"}\n'
        '{"hook_event_name":"Stop","session_id":"b","token":"wrong"}\n'
        '{"hook_event_name":"Stop","session_id":"c"}\n'
        'garbage\n'
        '{"hook_event_name":"Stop","session_id":"d","token":"${endpoint.token}"}');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received.map((event) => event.sessionId), ['a', 'd']);
    await server.stop();
  });

  test('a connection that never finishes is closed after a second', () async {
    final server = EventServer((_) {});
    final file = p.join(root.path, 'endpoint.json');
    await server.start(file);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, Endpoint.read(file)!.port);
    socket.add(utf8.encode('{"hook_event_name":'));
    final closed = await socket.drain<void>().then((_) => true).timeout(const Duration(seconds: 3), onTimeout: () => false);
    expect(closed, true);
    socket.destroy();
    await server.stop();
  });
}
