import 'package:deskling/core/bubble_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 15, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('shows text and hides on null', () {
    final bubble = BubbleState()..update('a', t0);
    expect(bubble.visibleText, 'a');
    bubble.update(null, at(10));
    expect(bubble.visibleText, isNull);
  });

  test('clicks inside the guard are ignored', () {
    final bubble = BubbleState()..update('a', t0);
    bubble.click(at(499));
    expect(bubble.visibleText, 'a');
    bubble.click(at(500));
    expect(bubble.visibleText, isNull);
  });

  test('a dismissed text stays hidden until it changes or is cleared', () {
    final bubble = BubbleState()
      ..update('a', t0)
      ..click(at(600));
    bubble.update('a', at(700));
    expect(bubble.visibleText, isNull);
    bubble.update('b', at(800));
    expect(bubble.visibleText, 'b');
    bubble.click(at(1400));
    bubble.clearDismissal();
    bubble.update('b', at(1500));
    expect(bubble.visibleText, 'b');
    bubble.click(at(1900));
    expect(bubble.visibleText, 'b', reason: 'reappearing restarts the guard');
  });

  test('hiding forgets the dismissal', () {
    final bubble = BubbleState()
      ..update('a', t0)
      ..click(at(600))
      ..update(null, at(700))
      ..update('a', at(800));
    expect(bubble.visibleText, 'a');
  });

  test('the same text does not restart the guard while visible', () {
    final bubble = BubbleState()
      ..update('a', t0)
      ..update('a', at(400));
    bubble.click(at(550));
    expect(bubble.visibleText, isNull);
  });
}
