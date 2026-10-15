import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../core/bubble_state.dart';
import '../core/event_server.dart';
import '../core/hook_event.dart';
import '../core/hook_installer.dart';
import '../core/hook_settings.dart';
import '../core/paths.dart';
import '../core/session_tracker.dart';
import '../core/skin.dart';
import '../core/strings.dart';
import 'login_item.dart';
import 'native.dart';
import 'pet_controller.dart';
import 'preferences.dart';
import 'sprite.dart';
import 'tray.dart';
import 'wsl_service.dart';

/// Wires hook events, the pet, the bubble and the tray together, like the macOS AppDelegate.
class Deskling {
  Deskling({required this.native, required this.preferences, required this.language});

  final Native native;
  final Preferences preferences;
  final Language language;
  final paths = AppPaths.current();
  final tracker = SessionTracker();
  final bubble = BubbleState();
  final sprites = SpriteCache();

  late final String _appDirectory = p.dirname(Platform.resolvedExecutable);
  late final String _defaultSkinDirectory = p.join(_appDirectory, 'data', 'flutter_assets', 'assets', 'skins', 'default');
  late final installer = HookInstaller(
    supportDirectory: paths.supportDirectory,
    bundledHook: p.join(_appDirectory, HookInstaller.helperName),
  );
  late final wsl = WslService(installedHook: installer.installedHook, isConnected: installer.isConnected);
  late final ConnectionTarget windowsTarget =
      ConnectionTarget(label: 'Windows', settingsPath: paths.claudeSettings, hookCommand: installer.installedHook);

  late final PetController pet;
  late final Tray tray;
  EventServer? _server;
  Timer? _stateTimer;

  String _t(Txt text) => text.of(language);

  /// Returns false when the default skin is missing; the caller quits.
  Future<bool> start() async {
    final skin = _currentSkin();
    if (skin == null) {
      Native.alert(_t(Txt.missingResources), _defaultSkinDirectory);
      return false;
    }
    Directory(paths.skinsDirectory).createSync(recursive: true);
    try {
      LoginItem.repairPath();
    } on Object {
      // The menu still shows the real state.
    }
    // Keep the installed helper in step with this version of the app.
    if (installer.isConnected(windowsTarget) || File(installer.installedHook).existsSync()) {
      unawaited(installer.copyHelper().catchError((Object _) {}));
    }

    pet = PetController(native, skin, preferences.sizeScale, startX: preferences.petX, monitorId: preferences.monitorId)
      ..onDropped = (x, monitorId) {
        preferences.petX = x;
        preferences.monitorId = monitorId;
      }
      ..onInspect = () => unawaited(tray.popUpSessions());
    pet.hidden = preferences.petHidden;
    pet.start();

    final server = EventServer((event) {
      tracker.apply(event, DateTime.now());
      if (event.requestsAttention || event.kind == HookKind.stop) bubble.clearDismissal();
      render();
    });
    if (!await server.start(paths.endpointFile)) {
      stderr.writeln('Deskling: hooks cannot reach this app until it is restarted.');
    }
    _server = server;

    _stateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tracker.tick(DateTime.now());
      render();
    });

    tray = Tray(language: language, state: _trayState, actions: _trayActions(), beforeOpen: () => unawaited(wsl.refresh()));
    await tray.start();
    unawaited(wsl.refresh());
    return true;
  }

  // Rendering

  void render() {
    final display = tracker.display;
    pet.display = display;
    final visible = preferences.bubblesEnabled && !preferences.petHidden;
    // A session that just finished is announced even while other sessions keep the pet busy.
    final spoken = tracker.justFinished ?? display;
    bubble.update(visible ? PetPresentation.bubble(spoken, language) : null, DateTime.now());
    pet.bubbleText = bubble.visibleText;
  }

  void bubbleClicked() {
    bubble.click(DateTime.now());
    pet.bubbleText = bubble.visibleText;
  }

  // Skins

  Skin? _currentSkin() {
    final path = preferences.skinPath;
    if (path != null) {
      final skin = SkinLoader.load(path);
      if (skin != null) return skin;
    }
    return SkinLoader.load(_defaultSkinDirectory);
  }

  void _applyCurrentSkin() {
    final skin = _currentSkin();
    if (skin == null) return;
    sprites.clear();
    pet.apply(skin: skin, sizeScale: preferences.sizeScale);
  }

  // Tray

  TrayState _trayState() {
    final userSkins = SkinLoader.list(paths.skinsDirectory).map((skin) => SkinItem(skin.directory, skin.name)).toList();
    final selected = userSkins.any((skin) => skin.path == preferences.skinPath) ? preferences.skinPath : null;
    final distros = wsl.latest;
    bool launchAtLogin;
    try {
      launchAtLogin = LoginItem.isEnabled;
    } on Object {
      launchAtLogin = false;
    }
    return TrayState(
      connected: installer.isConnected(windowsTarget),
      wsl: distros
          ?.map((d) => WslItem(d.name, connected: d.connected, readable: d.target != null))
          .toList(),
      sessions: tracker.summaries,
      skins: [SkinItem(null, _t(Txt.defaultSkin)), ...userSkins],
      selectedSkinPath: selected,
      sizeScale: preferences.sizeScale,
      bubblesEnabled: preferences.bubblesEnabled,
      petHidden: preferences.petHidden,
      launchAtLogin: launchAtLogin,
    );
  }

  TrayActions _trayActions() => TrayActions(
        toggleConnection: () => unawaited(_toggle(windowsTarget)),
        toggleWsl: (name) {
          final target = wsl.latest?.where((d) => d.name == name).firstOrNull?.target;
          if (target != null) unawaited(_toggle(target).then((_) => wsl.refresh()));
        },
        selectSkin: (path) {
          preferences.skinPath = path;
          _applyCurrentSkin();
        },
        openSkinsFolder: () {
          Directory(paths.skinsDirectory).createSync(recursive: true);
          unawaited(Process.run('explorer.exe', [paths.skinsDirectory]));
        },
        setSize: (scale) {
          preferences.sizeScale = scale;
          _applyCurrentSkin();
        },
        toggleBubbles: () {
          preferences.bubblesEnabled = !preferences.bubblesEnabled;
          render();
        },
        togglePet: () {
          preferences.petHidden = !preferences.petHidden;
          pet.hidden = preferences.petHidden;
          unawaited(preferences.petHidden ? windowManager.hide() : windowManager.show(inactive: true));
          render();
        },
        toggleLaunchAtLogin: () {
          try {
            LoginItem.set(!LoginItem.isEnabled);
          } on Object catch (error) {
            Native.alert(_t(Txt.loginItemFailed), '$error');
          }
        },
        quit: () => unawaited(quit()),
      );

  Future<void> _toggle(ConnectionTarget target) async {
    try {
      if (installer.isConnected(target)) {
        installer.disconnect(target);
      } else {
        await installer.connect(target);
      }
    } on InvalidSettingsException {
      await Clipboard.setData(ClipboardData(text: HookSettings.manualSnippet(target.hookCommand)));
      Native.alert(_t(Txt.invalidSettingsTitle), '${_t(Txt.invalidSettingsBody)}\n${target.settingsPath}');
    } on Object catch (error) {
      Native.alert(_t(Txt.connectFailed), '$error');
    }
  }

  Future<void> quit() async {
    _stateTimer?.cancel();
    await _server?.stop();
    await tray.destroy();
    exit(0);
  }
}
