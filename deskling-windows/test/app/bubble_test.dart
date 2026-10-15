import 'package:deskling/app/bubble.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measure includes padding and wraps at the maximum width', () {
    final short = Bubble.measure('done');
    expect(short.width, greaterThan(Bubble.padding * 2));
    expect(short.width, lessThan(Bubble.maxTextWidth));
    final long = Bubble.measure('a ' * 400);
    expect(long.width, lessThanOrEqualTo(Bubble.maxTextWidth + Bubble.padding * 2));
    expect(long.height, greaterThan(short.height * 3));
  });

  test('the first of several lines is bold and middle lines are dimmed', () {
    final spans = Bubble.span('app\ntitle\nbody').children!.cast<TextSpan>();
    expect(spans[0].style!.fontWeight, FontWeight.w600);
    expect(spans[1].style!.color, isNot(spans[2].style!.color));
    expect(spans[2].style!.fontWeight, FontWeight.w400);
    final single = Bubble.span('only').children!.cast<TextSpan>();
    expect(single.single.style!.fontWeight, FontWeight.w400);
  });

  testWidgets('the bubble box renders its text', (tester) async {
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Center(child: BubbleBox(text: 'app\nhello'))));
    expect(find.byType(RichText), findsOneWidget);
    expect(find.textContaining('hello', findRichText: true), findsOneWidget);
  });
}
