import 'dart:io';

import 'package:deskling/core/instance_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('deskling-lock-'));
  tearDown(() => root.deleteSync(recursive: true));

  /// Locks are per process, so the second claim has to come from another process.
  Future<int> claimInAnotherProcess(String path) async {
    final script = File(p.join(root.path, 'claim.dart'))
      ..writeAsStringSync('''
import 'dart:io';
import '${Uri.file(p.absolute('lib/core/instance_lock.dart'))}';
void main(List<String> args) => exit(InstanceLock.tryAcquire(args.first) == null ? 1 : 0);
''');
    return (await Process.run('dart', ['run', script.path, path])).exitCode;
  }

  test('only one process holds the lock, and it frees when that process ends', () async {
    final path = p.join(root.path, 'sub', 'instance.lock');
    final held = InstanceLock.tryAcquire(path);
    expect(held, isNotNull);
    expect(await claimInAnotherProcess(path), 1);
    held!.closeSync();
    expect(await claimInAnotherProcess(path), 0);
    expect(await claimInAnotherProcess(path), 0, reason: 'a process that exited released its lock');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
