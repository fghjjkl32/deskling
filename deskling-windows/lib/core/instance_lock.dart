import 'dart:io';

/// Keeps a second Deskling from running. The operating system releases the lock when the process ends,
/// so a crash never leaves a stale claim behind.
class InstanceLock {
  /// Returns the open, locked file to keep for the life of the process, or null when another process holds it.
  static RandomAccessFile? tryAcquire(String path) {
    RandomAccessFile? file;
    try {
      File(path).parent.createSync(recursive: true);
      file = File(path).openSync(mode: FileMode.append);
      file.lockSync(FileLock.exclusive);
      return file;
    } on FileSystemException {
      file?.closeSync();
      return null;
    }
  }
}
