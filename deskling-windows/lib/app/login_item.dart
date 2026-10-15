import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// "Launch at Login" through the current user's Run key.
class LoginItem {
  static const _path = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'Deskling';

  static String get _command => '"${Platform.resolvedExecutable}"';

  static RegistryKey _open() =>
      Registry.openPath(RegistryHive.currentUser, path: _path, desiredAccessRights: AccessRights.allAccess);

  static bool get isEnabled {
    final key = _open();
    try {
      return key.getStringValue(_name) != null;
    } finally {
      key.close();
    }
  }

  static void set(bool enabled) {
    final key = _open();
    try {
      if (enabled) {
        key.createValue(RegistryValue.string(_name, _command));
      } else if (key.getStringValue(_name) != null) {
        key.deleteValue(_name);
      }
    } finally {
      key.close();
    }
  }

  /// Moving the unzipped folder breaks the registered path, so point it at this copy of the app.
  static void repairPath() {
    final key = _open();
    try {
      final current = key.getStringValue(_name);
      if (current != null && current != _command) {
        key.createValue(RegistryValue.string(_name, _command));
      }
    } finally {
      key.close();
    }
  }
}
