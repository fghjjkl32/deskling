import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/deskling.dart';
import 'app/native.dart';
import 'app/pet_view.dart';
import 'app/preferences.dart';
import 'core/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locales = ui.PlatformDispatcher.instance.locales.map((locale) => locale.toLanguageTag()).toList();
  final language = Language.current(locales);
  // A second Deskling says so and quits, so a new download is not silently ignored.
  if (!Native.claimSingleInstance()) {
    Native.alert('Deskling', Txt.alreadyRunning.of(language));
    exit(0);
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Deskling',
      size: Size(96, 96),
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      alwaysOnTop: true,
      titleBarStyle: TitleBarStyle.hidden,
    ),
  );
  await windowManager.setAsFrameless();
  await windowManager.setHasShadow(false);
  await windowManager.setResizable(false);
  await windowManager.setBackgroundColor(Colors.transparent);

  final native = Native.find();
  if (native == null) {
    Native.alert('Deskling', 'The pet window could not be found.');
    exit(1);
  }
  native.makeToolWindow();

  final preferences = await Preferences.load();
  final app = Deskling(native: native, preferences: preferences, language: language);
  if (!await app.start()) exit(1);
  if (!preferences.petHidden) await windowManager.show(inactive: true);

  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: PetView(controller: app.pet, sprites: app.sprites, onBubbleClick: app.bubbleClicked),
    ),
  );
}
