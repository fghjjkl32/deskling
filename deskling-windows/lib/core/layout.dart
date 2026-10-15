import 'dart:math';

/// A rectangle in logical pixels, relative to the pet window.
class LogicalRect {
  const LogicalRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is LogicalRect && other.left == left && other.top == top && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'LogicalRect($left, $top, $width, $height)';
}

/// A rectangle in physical screen pixels: left, top, right, bottom.
class ScreenRect {
  const ScreenRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;

  bool contains(int x, int y) => x >= left && x < right && y >= top && y < bottom;

  @override
  bool operator ==(Object other) =>
      other is ScreenRect && other.left == left && other.top == top && other.right == right && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'ScreenRect($left, $top, $right, $bottom)';
}

/// Where the pet window goes and where the pet and bubble sit inside it.
class PetLayout {
  const PetLayout({required this.window, required this.pet, required this.bubble, required this.clickable});

  static const bubbleGap = 6.0;
  static const screenMargin = 4.0;

  /// Physical frame of the window.
  final ScreenRect window;

  /// Logical rectangles inside the window.
  final LogicalRect pet;
  final LogicalRect? bubble;

  /// Physical rectangles relative to the window that take clicks; empty means the whole window.
  final List<ScreenRect> clickable;

  /// `petOrigin` is the pet's physical top-left corner. Sizes are logical; `scale` converts them for this monitor.
  static PetLayout compute({
    required ScreenRect work,
    required double scale,
    required Point<int> petOrigin,
    required double petWidth,
    required double petHeight,
    double? bubbleWidth,
    double? bubbleHeight,
  }) {
    int px(double logical) => (logical * scale).round();
    final pet = ScreenRect(petOrigin.x, petOrigin.y, petOrigin.x + px(petWidth), petOrigin.y + px(petHeight));
    if (bubbleWidth == null || bubbleHeight == null) {
      return PetLayout(
        window: pet,
        pet: LogicalRect(0, 0, petWidth, petHeight),
        bubble: null,
        clickable: const [],
      );
    }
    final width = px(bubbleWidth);
    final height = px(bubbleHeight);
    final margin = px(screenMargin);
    final centered = pet.left + pet.width ~/ 2 - width ~/ 2;
    final left = max(work.left + margin, min(centered, work.right - width - margin));
    final top = max(work.top + margin, pet.top - px(bubbleGap) - height);
    final bubble = ScreenRect(left, top, left + width, top + height);
    final window = ScreenRect(
      min(pet.left, bubble.left),
      min(pet.top, bubble.top),
      max(pet.right, bubble.right),
      max(pet.bottom, bubble.bottom),
    );
    ScreenRect local(ScreenRect rect) =>
        ScreenRect(rect.left - window.left, rect.top - window.top, rect.right - window.left, rect.bottom - window.top);
    LogicalRect logical(ScreenRect rect) => LogicalRect((rect.left - window.left) / scale,
        (rect.top - window.top) / scale, rect.width / scale, rect.height / scale);
    return PetLayout(
      window: window,
      pet: logical(pet),
      bubble: logical(bubble),
      clickable: [local(pet), local(bubble)],
    );
  }
}
