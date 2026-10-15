import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

import '../core/session_tracker.dart';
import '../core/strings.dart';

class SkinItem {
  const SkinItem(this.path, this.name);

  /// Null for the bundled default pet.
  final String? path;
  final String name;
}

class WslItem {
  const WslItem(this.name, {required this.connected, required this.readable});

  final String name;
  final bool connected;
  final bool readable;
}

/// A snapshot of everything the tray menu shows, taken each time it opens.
class TrayState {
  const TrayState({
    required this.connected,
    required this.wsl,
    required this.sessions,
    required this.skins,
    required this.selectedSkinPath,
    required this.sizeScale,
    required this.bubblesEnabled,
    required this.petHidden,
    required this.launchAtLogin,
  });

  final bool connected;

  /// Null while the first WSL scan runs.
  final List<WslItem>? wsl;
  final List<SessionSummary> sessions;
  final List<SkinItem> skins;
  final String? selectedSkinPath;
  final double sizeScale;
  final bool bubblesEnabled;
  final bool petHidden;
  final bool launchAtLogin;
}

class TrayActions {
  const TrayActions({
    required this.toggleConnection,
    required this.toggleWsl,
    required this.selectSkin,
    required this.openSkinsFolder,
    required this.setSize,
    required this.toggleBubbles,
    required this.togglePet,
    required this.toggleLaunchAtLogin,
    required this.quit,
  });

  final void Function() toggleConnection;
  final void Function(String distro) toggleWsl;
  final void Function(String? path) selectSkin;
  final void Function() openSkinsFolder;
  final void Function(double scale) setSize;
  final void Function() toggleBubbles;
  final void Function() togglePet;
  final void Function() toggleLaunchAtLogin;
  final void Function() quit;
}

/// The notification-area icon and its menu, plus the session popup shown from the pet.
class Tray with TrayListener {
  Tray({required this.language, required this.state, required this.actions, required this.beforeOpen});

  static const sizes = [(Txt.sizeSmall, 0.75), (Txt.sizeMedium, 1.0), (Txt.sizeLarge, 1.5)];

  final Language language;
  final TrayState Function() state;
  final TrayActions actions;

  /// Starts background refreshes (WSL) so the next opening is up to date.
  final void Function() beforeOpen;

  Future<void> start() async {
    await trayManager.setIcon('assets/tray.ico');
    await trayManager.setToolTip('Deskling');
    trayManager.addListener(this);
  }

  Future<void> destroy() => trayManager.destroy();

  @override
  void onTrayIconMouseDown() => unawaited(_open(_fullMenu(state())));

  @override
  void onTrayIconRightMouseDown() => unawaited(_open(_fullMenu(state())));

  Future<void> popUpSessions() => _open(Menu(items: _sessionItems(state().sessions)));

  Future<void> _open(Menu menu) async {
    beforeOpen();
    await trayManager.setContextMenu(menu);
    // ignore: deprecated_member_use
    await trayManager.popUpContextMenu(bringAppToFront: true);
  }

  String _t(Txt text) => text.of(language);

  /// Windows menus treat `&` as a keyboard shortcut marker.
  static String _escape(String text) => text.replaceAll('&', '&&');

  Menu _fullMenu(TrayState s) => Menu(items: [
        MenuItem(label: _t(s.connected ? Txt.statusConnected : Txt.statusNotConnected), disabled: true),
        MenuItem(label: _t(s.connected ? Txt.disconnect : Txt.connect), onClick: (_) => actions.toggleConnection()),
        MenuItem.submenu(label: _t(Txt.wsl), submenu: Menu(items: _wslItems(s.wsl))),
        MenuItem.separator(),
        ..._sessionItems(s.sessions),
        MenuItem.separator(),
        MenuItem.submenu(
          label: _t(Txt.skin),
          submenu: Menu(items: [
            for (final skin in s.skins)
              MenuItem.checkbox(
                label: _escape(skin.name),
                checked: skin.path == s.selectedSkinPath,
                onClick: (_) => actions.selectSkin(skin.path),
              ),
            MenuItem.separator(),
            MenuItem(label: _t(Txt.openSkinsFolder), onClick: (_) => actions.openSkinsFolder()),
          ]),
        ),
        MenuItem.submenu(
          label: _t(Txt.size),
          submenu: Menu(items: [
            for (final (label, scale) in sizes)
              MenuItem.checkbox(
                label: _t(label),
                checked: (scale - s.sizeScale).abs() < 0.01,
                onClick: (_) => actions.setSize(scale),
              ),
          ]),
        ),
        MenuItem.checkbox(label: _t(Txt.showBubbles), checked: s.bubblesEnabled, onClick: (_) => actions.toggleBubbles()),
        MenuItem(label: _t(s.petHidden ? Txt.showPet : Txt.hidePet), onClick: (_) => actions.togglePet()),
        MenuItem.checkbox(
            label: _t(Txt.launchAtLogin), checked: s.launchAtLogin, onClick: (_) => actions.toggleLaunchAtLogin()),
        MenuItem.separator(),
        MenuItem(label: _t(Txt.quit), onClick: (_) => actions.quit()),
      ]);

  List<MenuItem> _wslItems(List<WslItem>? distros) {
    if (distros == null) return [MenuItem(label: '…', disabled: true)];
    if (distros.isEmpty) return [MenuItem(label: _t(Txt.wslNone), disabled: true)];
    return [
      for (final distro in distros)
        distro.readable
            ? MenuItem(
                label: _escape(Txt.wslTarget(distro.name, connected: distro.connected, language: language)),
                onClick: (_) => actions.toggleWsl(distro.name),
              )
            : MenuItem(label: _escape('${distro.name}: ${_t(Txt.wslUnreadable)}'), disabled: true),
    ];
  }

  List<MenuItem> _sessionItems(List<SessionSummary> sessions) => [
        MenuItem(label: _t(Txt.sessions), disabled: true),
        if (sessions.isEmpty) MenuItem(label: '    ${_t(Txt.noSessions)}', disabled: true),
        for (final session in sessions) ...[
          MenuItem(label: '    ${_escape(PetPresentation.sessionLine(session, language))}', disabled: true),
          if (PetPresentation.title(session.title) case final title?) MenuItem(label: '        ${_escape(title)}', disabled: true),
        ],
      ];
}
