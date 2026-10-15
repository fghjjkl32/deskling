import 'dart:math';

import 'package:deskling/core/layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const work = ScreenRect(0, 0, 1920, 1040);

  test('without a bubble the window is the pet', () {
    final layout = PetLayout.compute(work: work, scale: 1.5, petOrigin: const Point(100, 896), petWidth: 96, petHeight: 96);
    expect(layout.window, const ScreenRect(100, 896, 244, 1040));
    expect(layout.pet, const LogicalRect(0, 0, 96, 96));
    expect(layout.bubble, isNull);
    expect(layout.clickable, isEmpty);
  });

  test('the bubble sits centered above the pet and the window grows to hold both', () {
    final layout = PetLayout.compute(
        work: work, scale: 1, petOrigin: const Point(500, 944), petWidth: 96, petHeight: 96, bubbleWidth: 200, bubbleHeight: 60);
    expect(layout.window, const ScreenRect(448, 878, 648, 1040));
    expect(layout.bubble, const LogicalRect(0, 0, 200, 60));
    expect(layout.pet, const LogicalRect(52, 66, 96, 96));
    expect(layout.clickable, const [ScreenRect(52, 66, 148, 162), ScreenRect(0, 0, 200, 60)]);
  });

  test('the bubble stays inside the work area near the edges', () {
    final left = PetLayout.compute(
        work: work, scale: 1, petOrigin: const Point(0, 944), petWidth: 96, petHeight: 96, bubbleWidth: 284, bubbleHeight: 60);
    expect(left.window.left, 0);
    expect(left.bubble!.left, 4);
    final right = PetLayout.compute(
        work: work, scale: 1, petOrigin: const Point(1824, 944), petWidth: 96, petHeight: 96, bubbleWidth: 284, bubbleHeight: 60);
    expect(right.window.right, 1920);
    expect(right.bubble!.right, right.window.width - 4);
    final top = PetLayout.compute(
        work: work, scale: 1, petOrigin: const Point(500, 10), petWidth: 96, petHeight: 96, bubbleWidth: 200, bubbleHeight: 60);
    expect(top.window.top, 4);
  });

  test('scale converts logical sizes to pixels and back', () {
    final layout = PetLayout.compute(
        work: const ScreenRect(-1920, 0, 0, 1040),
        scale: 1.25,
        petOrigin: const Point(-1000, 920),
        petWidth: 96,
        petHeight: 96,
        bubbleWidth: 160,
        bubbleHeight: 48);
    expect(layout.window.height, 120 + 8 + 60);
    expect(layout.pet.width, 96);
    expect(layout.bubble!.width, 160);
    expect(layout.pet.bottom, closeTo(layout.window.height / 1.25, 0.001));
  });
}
