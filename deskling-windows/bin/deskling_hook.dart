import 'dart:async';
import 'dart:io';

import 'package:deskling/core/hook_event.dart';
import 'package:deskling/core/paths.dart';

const _inputLimit = 16 * 1024 * 1024;
const _timeout = Duration(seconds: 1);

/// A live loopback connect takes well under a millisecond. Windows retries a refused one for about two seconds,
/// so a short limit keeps hooks fast when the app was closed without cleaning up.
const _connectTimeout = Duration(milliseconds: 300);

/// Claude Code reads a hook's exit code and stdout, so this always exits 0 and prints nothing.
Future<void> main(List<String> arguments) async {
  try {
    final input = await _readInput();
    final endpoint = Endpoint.read(AppPaths.current().endpointFile);
    final line = HookEvent.compactLine(
      input,
      eventOverride: arguments.isNotEmpty ? arguments.first : null,
      token: endpoint?.token,
    );
    if (endpoint != null && line != null) {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, endpoint.port, timeout: _connectTimeout);
      socket.add(line);
      await socket.flush().timeout(_connectTimeout);
      await socket.close().timeout(_connectTimeout);
    }
  } on Object {
    // The pet is optional; Claude Code must never notice a failure here.
  }
  exit(0);
}

Future<List<int>> _readInput() {
  final bytes = <int>[];
  final done = Completer<List<int>>();
  late final StreamSubscription<List<int>> subscription;
  void finish() {
    if (done.isCompleted) return;
    subscription.cancel();
    done.complete(bytes);
  }

  subscription = stdin.listen(
    (chunk) {
      bytes.addAll(chunk.take(_inputLimit - bytes.length));
      if (bytes.length >= _inputLimit) finish();
    },
    onDone: finish,
    onError: (Object _) => finish(),
    cancelOnError: true,
  );
  Timer(_timeout, finish);
  return done.future;
}
