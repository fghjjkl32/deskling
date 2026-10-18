import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/layout.dart';
import '../core/motion.dart';
import '../core/session_tracker.dart';
import '../core/skin.dart';
import '../core/strings.dart';
import 'bubble.dart';
import 'native.dart';

/// Moves the pet window: walking along the taskbar, following the mouse while held, floating down when let go.
class PetController extends ChangeNotifier {
  PetController(this.native, this._skin, this._sizeScale, {double? startX, String? monitorId}) : _walk = WalkModel(0) {
    _applyAspect();
    _monitors = Native.monitors();
    final monitor = _monitors.firstWhere((m) => m.id == monitorId, orElse: _primary);
    final petWidth = (_petWidth * monitor.scale).round();
    final x = startX == null
        ? monitor.work.left + (monitor.work.width - petWidth) ~/ 2
        : startX.round().clamp(monitor.work.left, max(monitor.work.left, monitor.work.right - petWidth)).toInt();
    _origin = Point(x, monitor.work.bottom - (_petHeight * monitor.scale).round());
    _walk.place(x / monitor.scale);
    _scale = monitor.scale;
  }

  static const frameInterval = Duration(microseconds: 33333);

  final Native native;

  /// Called with the pet's x and monitor after the user drops it.
  void Function(double x, String monitorId)? onDropped;

  /// Called on a double-click or right-click on the pet.
  VoidCallback? onInspect;

  Skin _skin;
  double _sizeScale;
  double _aspect = 1;
  final WalkModel _walk;
  FallModel? _fall;
  bool _dragging = false;
  Point<int> _dragCursorStart = const Point(0, 0);
  Point<int> _dragOriginStart = const Point(0, 0);
  late Point<int> _origin;
  double _scale = 1;
  List<Monitor> _monitors = [];
  Timer? _timer;
  Timer? _monitorTimer;
  bool _hidden = false;
  PetDisplay _display = PetDisplay.idle;
  String? _bubbleText;
  PetLayout? _layout;
  ScreenRect? _appliedWindow;
  List<ScreenRect>? _appliedClickable;

  Skin get skin => _skin;
  PetLayout? get layout => _layout;
  String? get bubbleText => _bubbleText;
  bool get facingLeft => _walk.facingLeft;

  PetPose get pose =>
      PetPresentation.pose(_display.state, isWalking: _walk.isWalking, isHeld: _dragging, isFalling: _fall != null);

  double get _petHeight => _skin.height * _sizeScale;
  double get _petWidth => _petHeight * _aspect;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(frameInterval, (_) => _tick(frameInterval.inMicroseconds / 1e6));
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) => _monitors = Native.monitors());
    _tick(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _monitorTimer?.cancel();
    super.dispose();
  }

  set display(PetDisplay value) {
    if (value == _display) return;
    if (value.state != PetState.idle) _walk.stop();
    _display = value;
    notifyListeners();
  }

  set bubbleText(String? value) {
    if (value == _bubbleText) return;
    _bubbleText = value;
    _tick(0);
  }

  set hidden(bool value) {
    _hidden = value;
    _tick(0);
  }

  void apply({required Skin skin, required double sizeScale}) {
    _skin = skin;
    _sizeScale = sizeScale;
    _applyAspect();
    _tick(0);
  }

  void _applyAspect() {
    final frames = SpriteFrames.load(_skin.pathFor(PetPose.idle));
    _aspect = frames == null || frames.height == 0 ? 1 : frames.width / frames.height;
  }

  Monitor _primary() =>
      _monitors.firstWhere((m) => m.isPrimary, orElse: () => _monitors.isNotEmpty ? _monitors.first : _fallbackMonitor);

  static const _fallbackMonitor =
      Monitor(id: '0,0', bounds: ScreenRect(0, 0, 1920, 1080), work: ScreenRect(0, 0, 1920, 1040), scale: 1, isPrimary: true);

  /// The monitor under the pet's center, or the primary one when that monitor was removed.
  Monitor _currentMonitor() {
    final cx = _origin.x + (_petWidth * _scale).round() ~/ 2;
    final cy = _origin.y + (_petHeight * _scale).round() ~/ 2;
    return _monitors.firstWhere((m) => m.bounds.contains(cx, cy), orElse: _primary);
  }

  // Pointer input from the view.

  void grab() {
    _dragging = true;
    _fall = null;
    _walk.stop();
    _dragCursorStart = Native.cursor();
    _dragOriginStart = _origin;
    notifyListeners();
  }

  void dragMoved() {
    if (_dragging) _tick(0);
  }

  void drop() {
    if (!_dragging) return;
    _dragging = false;
    final monitor = _currentMonitor();
    final floor = monitor.work.bottom - (_petHeight * monitor.scale).round();
    _walk.place(_origin.x / monitor.scale);
    _fall = FallModel((floor - _origin.y) / monitor.scale);
    _tick(0);
    onDropped?.call(_origin.x.toDouble(), monitor.id);
  }

  void _tick(double dt) {
    if (_hidden) return;
    // A fast flick can lose the button-up event; end the drag once the button is really up.
    if (_dragging && !Native.isLeftButtonDown) {
      drop();
      return;
    }
    var monitor = _currentMonitor();
    if (monitor.scale != _scale) {
      // Crossing onto a monitor with another scale: keep the pixel position, restart the walk from it.
      _scale = monitor.scale;
      _walk.place(_origin.x / _scale);
    }
    final scale = _scale;

    if (_dragging) {
      final cursor = Native.cursor();
      final next = _dragOriginStart + (cursor - _dragCursorStart);
      if (next.x != _origin.x) _walk.face(left: next.x < _origin.x);
      _origin = next;
    } else {
      final width = (_petWidth * scale).round();
      final height = (_petHeight * scale).round();
      final work = monitor.work;
      final floor = work.bottom - height;
      final bounds = Span(work.left / scale, max(work.left / scale, (work.right - width) / scale));
      final fall = _fall;
      var y = floor;
      if (fall != null) {
        fall.step(dt);
        if (fall.hasLanded) _fall = null;
        y = floor - (fall.height * scale).round();
        _walk.clamp(bounds);
      } else if (_display.state == PetState.idle) {
        _walk.step(dt, bounds);
      } else {
        _walk.clamp(bounds);
      }
      _origin = Point((_walk.x * scale).round(), y);
    }

    final text = _bubbleText;
    final bubbleSize = text == null ? null : Bubble.measure(text);
    final layout = PetLayout.compute(
      work: monitor.work,
      scale: scale,
      petOrigin: _origin,
      petWidth: _petWidth,
      petHeight: _petHeight,
      bubbleWidth: bubbleSize?.width,
      bubbleHeight: bubbleSize?.height,
    );
    _layout = layout;
    if (layout.window != _appliedWindow) {
      if (native.setFrame(layout.window)) _appliedWindow = layout.window;
    }
    if (!listEquals(layout.clickable, _appliedClickable)) {
      // The pet keeps square corners so its feet and ears are never cut; only the bubble is rounded.
      final corner = (Bubble.cornerRadius * 2 * scale).round();
      native.setClickableArea(layout.clickable.isEmpty
          ? null
          : [for (final (index, rect) in layout.clickable.indexed) (rect, index == 0 ? 0 : corner)]);
      _appliedClickable = layout.clickable;
    }
    notifyListeners();
  }
}
