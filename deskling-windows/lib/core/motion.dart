import 'dart:math';

/// A closed range of horizontal positions, in logical pixels.
class Span {
  const Span(this.lower, this.upper);

  final double lower;
  final double upper;

  bool contains(double value) => value >= lower && value <= upper;
  double clamp(double value) => min(max(value, lower), upper);
}

typedef RandomIn = double Function(Span span);

final _random = Random();
double _uniform(Span span) => span.lower + _random.nextDouble() * (span.upper - span.lower);

class WalkModel {
  /// Logical pixels per second.
  static const speed = 40.0;
  static const restRange = Span(3, 8);
  static const _initialRest = 1.0;

  WalkModel(this._x);

  double _x;
  bool _facingLeft = false;
  bool _isWalking = false;
  double? _target;
  double _restRemaining = _initialRest;

  double get x => _x;
  bool get facingLeft => _facingLeft;
  bool get isWalking => _isWalking;

  void place(double x) {
    _x = x;
    stop();
  }

  void face({required bool left}) => _facingLeft = left;

  void stop() {
    _target = null;
    _isWalking = false;
    _restRemaining = _initialRest;
  }

  void clamp(Span bounds) => _x = bounds.clamp(_x);

  void step(double dt, Span bounds, {RandomIn random = _uniform}) {
    clamp(bounds);
    final target = _target;
    if (target == null) {
      _restRemaining -= dt;
      if (_restRemaining <= 0 && bounds.upper > bounds.lower) {
        final next = random(bounds);
        _target = next;
        _facingLeft = next < _x;
        _isWalking = true;
      }
      return;
    }
    final goal = bounds.clamp(target);
    final distance = goal - _x;
    final move = speed * dt;
    if (distance.abs() <= move) {
      _x = goal;
      _target = null;
      _isWalking = false;
      _restRemaining = random(restRange);
    } else {
      _facingLeft = distance < 0;
      _x += distance < 0 ? -move : move;
    }
  }
}

/// A slow, floaty descent to the floor after the pet is let go in mid-air.
/// `height` is the distance above the floor, so it works with any axis direction.
class FallModel {
  /// Logical pixels per second squared.
  static const acceleration = 300.0;

  /// Logical pixels per second.
  static const maxSpeed = 140.0;

  FallModel(this._height);

  double _height;
  double _speed = 0;
  bool _hasLanded = false;

  double get height => _height;
  bool get hasLanded => _hasLanded;

  void step(double dt) {
    _speed = min(_speed + acceleration * dt, maxSpeed);
    _height -= _speed * dt;
    if (_height <= 0) {
      _height = 0;
      _hasLanded = true;
    }
  }
}
