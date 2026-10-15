import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/skin.dart';

class SpriteAnimation {
  const SpriteAnimation(this.images, this.durations);

  final List<ui.Image> images;
  final List<double> durations;

  double get totalDuration => durations.fold(0, (sum, value) => sum + value);

  /// The frame to show `elapsed` seconds into a looping animation.
  ui.Image frameAt(double elapsed) {
    final total = totalDuration;
    if (images.length == 1 || total <= 0) return images.first;
    var t = elapsed % total;
    for (var i = 0; i < images.length; i++) {
      if (t < durations[i]) return images[i];
      t -= durations[i];
    }
    return images.last;
  }
}

/// Decodes each skin file once, off the UI isolate.
class SpriteCache {
  final _entries = <String, Future<SpriteAnimation?>>{};

  Future<SpriteAnimation?> load(String path) => _entries.putIfAbsent(path, () => _decode(path));

  void clear() => _entries.clear();

  static Future<SpriteAnimation?> _decode(String path) async {
    final frames = await Isolate.run(() => SpriteFrames.load(path));
    if (frames == null) return null;
    final images = <ui.Image>[];
    for (final pixels in frames.pixels) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(pixels, frames.width, frames.height, ui.PixelFormat.rgba8888, completer.complete);
      images.add(await completer.future);
    }
    return SpriteAnimation(images, frames.durations);
  }
}

/// Plays one skin file, mirrored when the pet faces left.
class SpriteView extends StatefulWidget {
  const SpriteView({super.key, required this.cache, required this.path, required this.speed, required this.facingLeft});

  final SpriteCache cache;
  final String path;
  final double speed;
  final bool facingLeft;

  @override
  State<SpriteView> createState() => _SpriteViewState();
}

class _SpriteViewState extends State<SpriteView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  SpriteAnimation? _animation;
  String? _loadedPath;
  double _elapsed = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker.start();
  }

  @override
  void didUpdateWidget(SpriteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  void _load() {
    final path = widget.path;
    widget.cache.load(path).then((animation) {
      if (!mounted || widget.path != path || animation == null) return;
      setState(() {
        _animation = animation;
        _loadedPath = path;
        _elapsed = 0;
      });
    });
  }

  void _onTick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    final animation = _animation;
    if (animation == null || animation.images.length < 2) return;
    final before = animation.frameAt(_elapsed);
    _elapsed += dt * widget.speed;
    if (!identical(before, animation.frameAt(_elapsed))) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    if (animation == null || _loadedPath == null) return const SizedBox.expand();
    return Transform.flip(
      flipX: widget.facingLeft,
      child: RawImage(
        image: animation.frameAt(_elapsed),
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
