import 'dart:io';
import 'dart:typed_data';

import 'package:deskling/core/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

late Directory root;

img.Image frame(int width, int height, {int durationMs = 250}) =>
    img.Image(width: width, height: height, numChannels: 4)
      ..clear(img.ColorRgba8(255, 0, 0, 255))
      ..frameDuration = durationMs;

Uint8List encode({int frames = 1, bool gif = false, int durationMs = 250, int width = 4, int height = 4}) {
  final image = frame(width, height, durationMs: durationMs);
  for (var i = 1; i < frames; i++) {
    image.addFrame(frame(width, height, durationMs: durationMs));
  }
  return gif ? img.encodeGif(image) : img.encodePng(image);
}

void write(String path, {int frames = 1, bool gif = false, int durationMs = 250, int width = 4, int height = 4}) =>
    File(path).writeAsBytesSync(encode(frames: frames, gif: gif, durationMs: durationMs, width: width, height: height));

String skinDirectory(String name) => (Directory(p.join(root.path, name))..createSync(recursive: true)).path;

void main() {
  setUp(() => root = Directory.systemTemp.createTempSync('deskling-skins-'));
  tearDown(() => root.deleteSync(recursive: true));

  test('a still PNG has one frame', () {
    final path = p.join(root.path, 'a.png');
    write(path);
    expect(SpriteFrames.load(path)?.pixels.length, 1);
    expect(SpriteFrames.load(path)?.pixels.first.length, 4 * 4 * 4);
  });

  test('animated GIF and PNG keep frames and delays', () {
    for (final (name, gif) in [('a.gif', true), ('b.png', false)]) {
      final path = p.join(root.path, name);
      write(path, frames: 3, gif: gif);
      final frames = SpriteFrames.load(path)!;
      expect(frames.pixels.length, 3, reason: name);
      expect(frames.totalDuration, closeTo(0.75, 0.01), reason: name);
    }
  });

  test('very short or missing delays become 0.1 seconds', () {
    final path = p.join(root.path, 'fast.png');
    write(path, frames: 2, durationMs: 0);
    expect(SpriteFrames.load(path)!.durations, [0.1, 0.1]);
  });

  test('broken, empty and oversized images are rejected', () {
    final broken = p.join(root.path, 'broken.png');
    File(broken).writeAsStringSync('not an image');
    expect(SpriteFrames.load(broken), isNull);
    final empty = p.join(root.path, 'empty.png');
    File(empty).writeAsBytesSync([]);
    expect(SpriteFrames.load(empty), isNull);
    final huge = p.join(root.path, 'huge.png');
    write(huge, width: SpriteFrames.maxDimension + 1, height: 2);
    expect(SpriteFrames.load(huge), isNull);
    expect(SpriteFrames.load(p.join(root.path, 'missing.png')), isNull);
  });

  test('the total pixel budget rejects animations that are too large in sum', () {
    final path = p.join(root.path, 'budget.png');
    write(path, frames: 3);
    expect(SpriteFrames.load(path, maxTotalPixels: 40), isNull);
    expect(SpriteFrames.load(path, maxTotalPixels: 48)?.pixels.length, 3);
    expect(SpriteFrames.maxTotalPixels, 64000000);
  });

  test('a full skin loads every pose', () {
    final directory = skinDirectory('full');
    for (final pose in PetPose.values) {
      write(p.join(directory, '${pose.name}.png'));
    }
    final skin = SkinLoader.load(directory)!;
    expect(skin.id, 'full');
    expect(skin.name, 'full');
    expect(skin.height, 96);
    for (final pose in PetPose.values) {
      expect(p.basename(skin.pathFor(pose)), '${pose.name}.png');
    }
  });

  test('missing poses fall back to idle', () {
    final directory = skinDirectory('partial');
    write(p.join(directory, 'idle.gif'), gif: true);
    final skin = SkinLoader.load(directory)!;
    expect(p.basename(skin.pathFor(PetPose.walk)), 'idle.gif');
    expect(p.basename(skin.pathFor(PetPose.done)), 'idle.gif');
  });

  test('held and falling poses borrow the walk cycle at running speed', () {
    final directory = skinDirectory('walker');
    write(p.join(directory, 'idle.png'));
    write(p.join(directory, 'walk.png'));
    final skin = SkinLoader.load(directory)!;
    expect(p.basename(skin.pathFor(PetPose.drag)), 'walk.png');
    expect(p.basename(skin.pathFor(PetPose.fall)), 'walk.png');
    expect(skin.playbackSpeed(PetPose.drag), Skin.borrowedWalkSpeed);
    expect(skin.playbackSpeed(PetPose.fall), Skin.borrowedWalkSpeed);
    expect(skin.playbackSpeed(PetPose.walk), 1);
  });

  test('falling borrows the drag image at normal speed', () {
    final directory = skinDirectory('runner');
    for (final name in ['idle', 'walk', 'drag']) {
      write(p.join(directory, '$name.png'));
    }
    final skin = SkinLoader.load(directory)!;
    expect(p.basename(skin.pathFor(PetPose.drag)), 'drag.png');
    expect(p.basename(skin.pathFor(PetPose.fall)), 'drag.png');
    expect(skin.playbackSpeed(PetPose.drag), 1);
    expect(skin.playbackSpeed(PetPose.fall), 1);
  });

  test('the held pose falls back to idle without a walk cycle', () {
    final directory = skinDirectory('still');
    write(p.join(directory, 'idle.png'));
    final skin = SkinLoader.load(directory)!;
    expect(p.basename(skin.pathFor(PetPose.drag)), 'idle.png');
    expect(skin.playbackSpeed(PetPose.drag), 1);
  });

  test('a skin without a usable idle is rejected', () {
    final noIdle = skinDirectory('no-idle');
    write(p.join(noIdle, 'walk.png'));
    expect(SkinLoader.load(noIdle), isNull);
    final brokenIdle = skinDirectory('broken-idle');
    File(p.join(brokenIdle, 'idle.png')).writeAsStringSync('x');
    expect(SkinLoader.load(brokenIdle), isNull);
  });

  test('a broken non-idle pose falls back to idle', () {
    final directory = skinDirectory('broken-walk');
    write(p.join(directory, 'idle.png'));
    File(p.join(directory, 'walk.png')).writeAsStringSync('x');
    expect(p.basename(SkinLoader.load(directory)!.pathFor(PetPose.walk)), 'idle.png');
  });

  test('upper-case file names are accepted', () {
    final directory = skinDirectory('upper');
    write(p.join(directory, 'IDLE.PNG'));
    write(p.join(directory, 'Walk.GIF'), gif: true);
    final skin = SkinLoader.load(directory)!;
    expect(p.basename(skin.pathFor(PetPose.idle)), 'IDLE.PNG');
    expect(p.basename(skin.pathFor(PetPose.walk)), 'Walk.GIF');
  });

  test('skin.json overrides name and height', () {
    final directory = skinDirectory('named');
    write(p.join(directory, 'idle.png'));
    File(p.join(directory, 'skin.json')).writeAsStringSync('{"name":"내 펫","height":140}');
    final skin = SkinLoader.load(directory)!;
    expect(skin.name, '내 펫');
    expect(skin.height, 140);
  });

  test('skin.json problems fall back to defaults', () {
    final cases = [('{ broken', 96.0), ('{"name":"","height":"big"}', 96.0), ('{"height":5}', 16.0), ('{"height":9999}', 512.0)];
    for (final (index, (json, height)) in cases.indexed) {
      final directory = skinDirectory('case$index');
      write(p.join(directory, 'idle.png'));
      File(p.join(directory, 'skin.json')).writeAsStringSync(json);
      final skin = SkinLoader.load(directory)!;
      expect(skin.name, 'case$index');
      expect(skin.height, height);
    }
  });

  test('list returns only valid skins sorted by name', () {
    write(p.join(skinDirectory('b'), 'idle.png'));
    write(p.join(skinDirectory('a'), 'idle.png'));
    skinDirectory('empty');
    File(p.join(root.path, 'stray-file.txt')).writeAsStringSync('x');
    expect(SkinLoader.list(root.path).map((skin) => skin.id), ['a', 'b']);
    expect(SkinLoader.list(p.join(root.path, 'missing')), isEmpty);
  });

  test('the bundled default skin loads with its animations', () {
    final skin = SkinLoader.load(p.join('assets', 'skins', 'default'))!;
    expect(skin.name, 'Deskling');
    for (final pose in [PetPose.idle, PetPose.walk, PetPose.working, PetPose.waiting, PetPose.done]) {
      expect(p.basename(skin.pathFor(pose)), '${pose.name}.png');
      expect(SpriteFrames.load(skin.pathFor(pose)), isNotNull, reason: pose.name);
    }
    expect(p.basename(skin.pathFor(PetPose.drag)), 'walk.png');
    expect(SpriteFrames.load(skin.pathFor(PetPose.idle))?.pixels.length, 2);
    expect(SpriteFrames.load(skin.pathFor(PetPose.walk))?.pixels.length, 19);
    expect(SpriteFrames.load(skin.pathFor(PetPose.done))?.pixels.length, 10);
  });
}
