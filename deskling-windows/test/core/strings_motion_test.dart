import 'package:deskling/core/motion.dart';
import 'package:deskling/core/session_tracker.dart';
import 'package:deskling/core/skin.dart';
import 'package:deskling/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('strings', () {
    test('language follows the first preferred language', () {
      expect(Language.current(['ko-KR', 'en-US']), Language.korean);
      expect(Language.current(['ko_KR']), Language.korean);
      expect(Language.current(['en-US', 'ko-KR']), Language.english);
      expect(Language.current(['ja-JP']), Language.english);
      expect(Language.current([]), Language.english);
    });

    test('every text has both languages and Korean sentences end politely', () {
      for (final text in Txt.values) {
        expect(text.korean, isNotEmpty, reason: '$text');
        expect(text.english, isNotEmpty, reason: '$text');
        if (text.korean.endsWith('.')) expect(text.korean, endsWith('니다.'), reason: '$text');
      }
    });

    test('WSL target labels', () {
      expect(Txt.wslTarget('Ubuntu', connected: false, language: Language.korean), 'Ubuntu: Claude Code 연결하기');
      expect(Txt.wslTarget('Ubuntu', connected: true, language: Language.english), 'Ubuntu: Disconnect');
    });

    test('bubble shows the prompt as a title between project and message', () {
      const done = PetDisplay(state: PetState.done, projectName: 'app', title: '  말풍선에\n제목을   추가해 줘 ');
      expect(PetPresentation.bubble(done, Language.korean), 'app\n말풍선에 제목을 추가해 줘\n작업을 마쳤습니다.');
      const waiting = PetDisplay(state: PetState.waiting, message: 'Need permission', title: 'fix the build');
      expect(PetPresentation.bubble(waiting, Language.english), 'fix the build\nNeed permission');
      const blank = PetDisplay(state: PetState.done, projectName: 'app', title: ' \n ');
      expect(PetPresentation.bubble(blank, Language.english), 'app\nFinished working.');
    });

    test('title is truncated', () {
      expect(PetPresentation.title('가' * 200)!.runes.length, PetPresentation.maxTitleLength + 1);
      expect(PetPresentation.title(null), isNull);
    });

    test('pose for state', () {
      expect(PetPresentation.pose(PetState.idle, isWalking: false), PetPose.idle);
      expect(PetPresentation.pose(PetState.idle, isWalking: true), PetPose.walk);
      expect(PetPresentation.pose(PetState.working, isWalking: false, isHeld: true, isFalling: true), PetPose.drag);
      expect(PetPresentation.pose(PetState.waiting, isWalking: false, isFalling: true), PetPose.fall);
      expect(PetPresentation.pose(PetState.working, isWalking: true), PetPose.working);
      expect(PetPresentation.pose(PetState.waiting, isWalking: false), PetPose.waiting);
      expect(PetPresentation.pose(PetState.done, isWalking: false), PetPose.done);
    });

    test('bubble only for waiting and done', () {
      expect(PetPresentation.bubble(const PetDisplay(state: PetState.idle, projectName: 'app'), Language.korean), isNull);
      expect(PetPresentation.bubble(const PetDisplay(state: PetState.working, projectName: 'app'), Language.korean), isNull);
    });

    test('bubble text', () {
      expect(
          PetPresentation.bubble(
              const PetDisplay(state: PetState.waiting, projectName: 'app', message: 'Need permission'), Language.korean),
          'app\nNeed permission');
      expect(PetPresentation.bubble(const PetDisplay(state: PetState.waiting), Language.korean), '입력을 기다리고 있습니다.');
      expect(PetPresentation.bubble(const PetDisplay(state: PetState.waiting, projectName: 'app', message: '  '), Language.english),
          'app\nWaiting for your input.');
      expect(PetPresentation.bubble(const PetDisplay(state: PetState.done, projectName: 'app'), Language.korean),
          'app\n작업을 마쳤습니다.');
    });

    test('bubble truncates and collapses', () {
      final long = PetPresentation.bubble(PetDisplay(state: PetState.waiting, message: 'a' * 500), Language.english)!;
      expect(long.runes.length, PetPresentation.maxMessageLength + 1);
      expect(long, endsWith('…'));
      expect(
          PetPresentation.bubble(
              const PetDisplay(state: PetState.waiting, message: 'Run\n\n  this   command\t now'), Language.english),
          'Run this command now');
      final project = PetPresentation.bubble(PetDisplay(state: PetState.done, projectName: 'p' * 60), Language.english)!;
      expect(project.split('\n').first, '${'p' * 40}…');
    });

    test('session line', () {
      expect(PetPresentation.sessionLine(const SessionSummary(projectName: 'app', state: PetState.working), Language.korean),
          'app — 작업 중');
      expect(PetPresentation.sessionLine(const SessionSummary(projectName: null, state: PetState.waiting), Language.english),
          'Unnamed — Waiting for input');
    });
  });

  group('walk', () {
    const bounds = Span(0, 1000);

    test('rests, then walks toward the target', () {
      final model = WalkModel(100);
      model.step(0.5, bounds, random: (_) => 500);
      expect(model.isWalking, false);
      model.step(0.6, bounds, random: (_) => 500);
      expect(model.isWalking, true);
      expect(model.facingLeft, false);
      model.step(1, bounds, random: (_) => 500);
      expect(model.x, closeTo(100 + WalkModel.speed, 0.001));
    });

    test('face turns the pet', () {
      final model = WalkModel(100)..face(left: true);
      expect(model.facingLeft, true);
      model.face(left: false);
      expect(model.facingLeft, false);
    });

    test('faces left when the target is behind', () {
      final model = WalkModel(800);
      model.step(2, bounds, random: (_) => 200);
      model.step(1, bounds, random: (_) => 200);
      expect(model.facingLeft, true);
      expect(model.x, closeTo(800 - WalkModel.speed, 0.001));
    });

    test('arrives exactly and rests', () {
      final model = WalkModel(100);
      model.step(2, bounds, random: (_) => 110);
      model.step(1, bounds, random: (_) => 4);
      expect(model.x, 110);
      expect(model.isWalking, false);
      model.step(3.9, bounds, random: (_) => 900);
      expect(model.isWalking, false);
      model.step(0.2, bounds, random: (_) => 900);
      expect(model.isWalking, true);
    });

    test('never leaves the bounds', () {
      final model = WalkModel(500);
      for (var i = 0; i < 5000; i++) {
        model.step(1 / 30, bounds);
        expect(bounds.contains(model.x), true);
      }
    });

    test('a position outside the bounds is pulled back', () {
      final model = WalkModel(5000);
      model.step(0, bounds, random: (_) => 0);
      expect(model.x, 1000);
      model.clamp(const Span(0, 300));
      expect(model.x, 300);
    });

    test('a target outside shrunk bounds is pulled back', () {
      final model = WalkModel(100);
      model.step(2, bounds, random: (_) => 900);
      for (var i = 0; i < 600; i++) {
        model.step(0.1, const Span(0, 300), random: (_) => 5);
      }
      expect(model.x, lessThanOrEqualTo(300));
    });

    test('zero-width bounds stay still', () {
      final model = WalkModel(50);
      for (var i = 0; i < 100; i++) {
        model.step(1, const Span(50, 50), random: (_) => 50);
      }
      expect(model.x, 50);
      expect(model.isWalking, false);
    });

    test('place and stop cancel walking', () {
      final model = WalkModel(100);
      model.step(2, bounds, random: (_) => 900);
      expect(model.isWalking, true);
      model.stop();
      expect(model.isWalking, false);
      model.step(2, bounds, random: (_) => 900);
      model.place(400);
      expect(model.x, 400);
      expect(model.isWalking, false);
    });
  });

  group('fall', () {
    test('descends without exceeding the maximum speed', () {
      final model = FallModel(1000);
      var previous = model.height;
      for (var i = 0; i < 100 && !model.hasLanded; i++) {
        model.step(0.1);
        expect(model.height, lessThan(previous));
        expect(previous - model.height, lessThanOrEqualTo(FallModel.maxSpeed * 0.1 + 0.001));
        previous = model.height;
      }
    });

    test('starts slower than the maximum speed', () {
      final model = FallModel(1000)..step(0.1);
      expect(model.height, closeTo(1000 - FallModel.acceleration * 0.1 * 0.1, 0.001));
      expect(model.hasLanded, false);
    });

    test('lands exactly on the floor', () {
      final model = FallModel(5);
      for (var i = 0; i < 100 && !model.hasLanded; i++) {
        model.step(0.1);
      }
      expect(model.hasLanded, true);
      expect(model.height, 0);
    });

    test('lands at once when already on or below the floor', () {
      final model = FallModel(-60)..step(0);
      expect(model.hasLanded, true);
      expect(model.height, 0);
    });
  });
}
