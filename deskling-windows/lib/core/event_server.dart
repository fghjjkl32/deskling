import 'dart:async';
import 'dart:io';

import 'hook_event.dart';
import 'paths.dart';

/// Listens on 127.0.0.1 for hook lines and publishes the endpoint for the helper.
class EventServer {
  EventServer(this.onEvent);

  static const connectionTimeout = Duration(seconds: 1);

  final void Function(HookEvent event) onEvent;
  ServerSocket? _server;
  late final String _token = Endpoint.newToken();

  Future<bool> start(String endpointFile) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      server.listen(_handle, onError: (Object _) {});
      final file = File(endpointFile);
      file.parent.createSync(recursive: true);
      final temporary = File('$endpointFile.tmp');
      temporary.writeAsStringSync(Endpoint(port: server.port, token: _token).encode(), flush: true);
      temporary.renameSync(endpointFile);
      return true;
    } on Object catch (error) {
      stderr.writeln('Deskling: could not start the event server: $error');
      return false;
    }
  }

  Future<void> stop() async => _server?.close();

  void _handle(Socket socket) {
    final splitter = EventLineSplitter();
    late final StreamSubscription<List<int>> subscription;
    final timer = Timer(connectionTimeout, () {
      subscription.cancel();
      socket.destroy();
    });
    void deliver(List<int> line) {
      final event = HookEvent.parse(line);
      if (event != null && event.token == _token) onEvent(event);
    }

    subscription = socket.listen(
      (chunk) => splitter.append(chunk).forEach(deliver),
      onDone: () {
        timer.cancel();
        final rest = splitter.finish();
        if (rest != null) deliver(rest);
        socket.destroy();
      },
      onError: (Object _) {
        timer.cancel();
        socket.destroy();
      },
      cancelOnError: true,
    );
  }
}
